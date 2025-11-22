# file: rag_backend/main.py
import os
import uvicorn
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel

# UPDATED IMPORTS -----------------------------------------
from langchain_community.llms import Ollama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.document_loaders import PyPDFLoader
from langchain_community.vectorstores import Chroma
# This line below is the specific fix for your error:
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
# ---------------------------------------------------------

app = FastAPI()

# 1. SETUP: Initialize Llama 3 and Embeddings (requires Ollama running)
llm = Ollama(model="llama3")
embeddings = OllamaEmbeddings(model="llama3")

# Global variable to store the vector database in memory
vector_db = None

class QuestionRequest(BaseModel):
    query: str

@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):
    global vector_db
    
    # Save the uploaded file temporarily
    file_location = f"temp_{file.filename}"
    with open(file_location, "wb+") as file_object:
        file_object.write(file.file.read())

    # 2. INGESTION: Load PDF, split text, and create embeddings
    print("Processing PDF...")
    loader = PyPDFLoader(file_location)
    documents = loader.load()
    
    # Split text into chunks (1000 characters each)
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    chunks = text_splitter.split_documents(documents)

    # 3. STORAGE: Store chunks in ChromaDB (Vector Store)
    vector_db = Chroma.from_documents(
        documents=chunks, 
        embedding=embeddings,
        persist_directory="./chroma_db"
    )
    
    return {"status": "success", "message": "PDF processed. You can now ask questions!"}

@app.post("/ask")
async def ask_question(request: QuestionRequest):
    global vector_db
    if vector_db is None:
        raise HTTPException(status_code=400, detail="Please upload a PDF first.")

    # 4. RETRIEVAL: Search for relevant chunks and generate answer
    retriever = vector_db.as_retriever()
    qa_chain = RetrievalQA.from_chain_type(
        llm=llm,
        chain_type="stuff",
        retriever=retriever,
        return_source_documents=True
    )
    
    # Ask Llama 3
    response = qa_chain.invoke({"query": request.query})
    return {"answer": response["result"]}

if __name__ == "__main__":
    # Run on localhost:8000
    uvicorn.run(app, host="0.0.0.0", port=8000)