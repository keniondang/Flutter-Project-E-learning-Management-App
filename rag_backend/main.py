import os
import shutil
import uvicorn
from typing import List
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel

# --- LangChain & RAG Imports ---
from langchain_groq import ChatGroq
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.document_loaders import PyPDFLoader
from langchain_chroma import Chroma
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain_core.documents import Document

# --- CONFIGURATION ---
class Config:
    MODEL_NAME = "llama3-8b-8192"  # Ensure you have this pulled in 
    EMBEDDING_MODEL = "all-MiniLM-L6-v2" 
    CHROMA_PATH = "chroma_db_storage"
    CHUNK_SIZE = 1000
    CHUNK_OVERLAP = 200
    # Search settings
    TOP_K = 4 

app = FastAPI()

# --- GLOBAL STATE ---
# We keep these global to persist memory across calls
vector_store = None
conversation_chain = None
memory = None

# --- HELPER CLASSES (The "Brain" Logic) ---

def init_system():
    """Initializes the Vector DB and Chat Chain on startup."""
    global vector_store, conversation_chain, memory
    
    # 1. Setup Embeddings
    print(f"🔹 Initializing Embeddings ({Config.EMBEDDING_MODEL})...")
    embeddings = HuggingFaceEmbeddings(model=Config.EMBEDDING_MODEL)

    # 2. Load or Create Vector Store
    # We use ChromaDB to store the PDF info
    vector_store = Chroma(
        persist_directory=Config.CHROMA_PATH,
        embedding_function=embeddings,
        collection_name="pdf_knowledge_base"
    )
    
    # 3. Setup Memory (Stores chat history)
    memory = ConversationBufferMemory(
        memory_key="chat_history",
        return_messages=True,
        output_key='answer' 
    )

    # 4. Setup Retrieval Chain (Connects LLM + Memory + DB)
    # Only create chain if DB has data, otherwise wait for upload
    if vector_store._collection.count() > 0:
        create_chain()
        print("✅ System Ready: Loaded existing knowledge base.")
    else:
        print("⚠️ System Ready: Database empty. Waiting for PDF upload.")

def create_chain():
    """Creates the conversational chain using the current vector store."""
    global vector_store, conversation_chain, memory
    
    llm = ChatGroq(
        model=Config.MODEL_NAME,
        temperature=0.3, # Low temperature for factual accuracy
        api_key=os.environ.get("GROQ_API_KEY")
    )
    
    retriever = vector_store.as_retriever(search_kwargs={"k": Config.TOP_K})
    
    conversation_chain = ConversationalRetrievalChain.from_llm(
        llm=llm,
        retriever=retriever,
        memory=memory,
        return_source_documents=True, # vital for citations
        verbose=True
    )

def format_response_with_citations(response_dict):
    """
    Extracts the answer and formats source citations nicely.
    Matches the logic you saw in 'utils.py'
    """
    answer = response_dict['answer']
    sources = response_dict.get('source_documents', [])
    
    if not sources:
        return answer
    
    # Deduplicate sources
    seen_files = set()
    formatted_sources = []
    
    for doc in sources:
        source_name = doc.metadata.get('source', 'Unknown Document')
        # Sometimes path is full, just get filename
        filename = os.path.basename(source_name)
        
        if filename not in seen_files:
            formatted_sources.append(f"• {filename}")
            seen_files.add(filename)
            
    if formatted_sources:
        citation_text = "\n\n**Sources:**\n" + "\n".join(formatted_sources)
        return answer + citation_text
    
    return answer

# --- API ENDPOINTS ---

class QueryRequest(BaseModel):
    query: str

@app.on_event("startup")
async def startup():
    init_system()

@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):
    global vector_store
    
    temp_filename = f"temp_{file.filename}"
    try:
        # 1. Save File Temporarily
        with open(temp_filename, "wb+") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        print(f"📥 Processing {file.filename}...")

        # 2. Load and Split PDF
        loader = PyPDFLoader(temp_filename)
        documents = loader.load()
        
        # Add metadata so we know which file the info came from
        for doc in documents:
            doc.metadata['source'] = file.filename

        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=Config.CHUNK_SIZE, 
            chunk_overlap=Config.CHUNK_OVERLAP
        )
        chunks = text_splitter.split_documents(documents)
        
        # 3. Add to Vector DB
        # This automatically persists in Chroma
        vector_store.add_documents(chunks)
        
        # 4. Re-initialize Chain to ensure it uses new data
        create_chain()
        
        return {"status": "success", "message": f"Learned from {file.filename}!"}
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

@app.post("/ask")
async def ask(request: QueryRequest):
    global conversation_chain
    
    if conversation_chain is None:
        raise HTTPException(status_code=400, detail="Database is empty. Upload a PDF first.")
        
    try:
        # Run the chain (Handles history + Retrieval + Generation)
        # We pass only the question; memory handles the history automatically
        response = conversation_chain.invoke({"question": request.query})
        
        # Format the final text
        final_text = format_response_with_citations(response)
        
        return {"answer": final_text}
        
    except Exception as e:
        print(f"❌ Error generating answer: {e}")
        raise HTTPException(status_code=500, detail="Processing failed.")

@app.post("/reset")
async def reset_memory():
    """Clears the chat history so the bot forgets previous context."""
    global memory
    if memory:
        memory.clear()
    return {"status": "memory_cleared"}

if __name__ == "__main__":
    # Ensure database folder exists
    if not os.path.exists(Config.CHROMA_PATH):
        os.makedirs(Config.CHROMA_PATH)
        
    uvicorn.run(app, host="0.0.0.0", port=8000)