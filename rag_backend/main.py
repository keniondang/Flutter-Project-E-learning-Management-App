# file: rag_backend/main.py
import os
import glob
import uvicorn
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel

# LangChain Imports
from langchain_community.llms import Ollama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.document_loaders import PyPDFLoader
from langchain_community.vectorstores import Chroma
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA

app = FastAPI()

# --- CONFIGURATION ---
# 1. Update this if you use a different model (e.g., "llama3.1")
MODEL_NAME = "llama3:8b" 
# 2. Folder where your base learning guides live
KNOWLEDGE_BASE_FOLDER = "knowledge_base"

# Initialize Global Variables
llm = Ollama(model=MODEL_NAME)
embeddings = OllamaEmbeddings(model=MODEL_NAME)
vector_db = None

def process_pdf(file_path: str):
    """Helper function to read a PDF and split it into chunks."""
    print(f"Loading: {file_path}")
    loader = PyPDFLoader(file_path)
    documents = loader.load()
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    return text_splitter.split_documents(documents)

@app.on_event("startup")
async def startup_event():
    """Runs automatically when the server starts."""
    global vector_db
    print("--- 🚀 STARTING AI SERVER ---")
    
    # Check if knowledge_base folder exists
    if not os.path.exists(KNOWLEDGE_BASE_FOLDER):
        os.makedirs(KNOWLEDGE_BASE_FOLDER)
        print(f"Created folder '{KNOWLEDGE_BASE_FOLDER}'. Please put your base PDFs here!")
        return

    # Find all PDFs in the folder
    pdf_files = glob.glob(f"{KNOWLEDGE_BASE_FOLDER}/*.pdf")
    
    if not pdf_files:
        print("No base PDFs found. Chatbot will start empty.")
        return

    # Load all base PDFs
    all_chunks = []
    for pdf_path in pdf_files:
        try:
            chunks = process_pdf(pdf_path)
            all_chunks.extend(chunks)
        except Exception as e:
            print(f"Error loading {pdf_path}: {e}")

    # Build the Vector Database
    if all_chunks:
        print(f"🧠 Ingesting {len(all_chunks)} chunks into memory...")
        vector_db = Chroma.from_documents(
            documents=all_chunks, 
            embedding=embeddings,
            persist_directory="./chroma_db"
        )
        print("✅ Knowledge Base Loaded! System is ready.")
    else:
        print("Warning: Base PDFs were empty.")

class QuestionRequest(BaseModel):
    query: str

@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):
    global vector_db
    
    # Save the uploaded file temporarily
    file_location = f"temp_{file.filename}"
    with open(file_location, "wb+") as file_object:
        file_object.write(file.file.read())

    try:
        # Process the new file
        new_chunks = process_pdf(file_location)
        
        if vector_db is None:
            # If DB was empty, create it now
            vector_db = Chroma.from_documents(
                documents=new_chunks, 
                embedding=embeddings,
                persist_directory="./chroma_db"
            )
        else:
            # If DB exists, ADD the new knowledge to it
            print("Appending new file to existing knowledge base...")
            vector_db.add_documents(new_chunks)
            
        return {"status": "success", "message": "File analyzed! I can now answer questions about it AND the base guide."}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Cleanup: Remove temp file
        if os.path.exists(file_location):
            os.remove(file_location)

@app.post("/ask")
async def ask_question(request: QuestionRequest):
    global vector_db
    
    if vector_db is None:
        raise HTTPException(status_code=400, detail="I have no knowledge yet. Please upload a file or check the server logs.")

    # Retrieve answer
    retriever = vector_db.as_retriever()
    qa_chain = RetrievalQA.from_chain_type(
        llm=llm,
        chain_type="stuff",
        retriever=retriever,
        return_source_documents=True
    )
    
    print(f"Thinking about: {request.query}")
    response = qa_chain.invoke({"query": request.query})
    return {"answer": response["result"]}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)