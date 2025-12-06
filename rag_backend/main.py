import os
import shutil
from typing import List

import uvicorn
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# LangChain + RAG
from langchain_groq import ChatGroq
from langchain_community.document_loaders import PyPDFLoader
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_chroma import Chroma
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.messages import HumanMessage, AIMessage


# ================================
# CONFIG
# ================================
class Config:
    GROQ_API_KEY = os.getenv("GROQ_API_KEY")
    MODEL_NAME = "llama-3.1-8b-instant"
    EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
    CHROMA_PATH = "chroma_db"
    TOP_K = 4
    CHUNK_SIZE = 1000
    CHUNK_OVERLAP = 200


# ================================
# GLOBALS
# ================================
app = FastAPI()

# CORS so Flutter Web (GitHub Pages) can call Railway
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # for dev; you can restrict to your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

vector_store = None
retriever = None
llm = None
chat_history: List = []


# ================================
# INIT / REBUILD RAG
# ================================
def rebuild_rag():
    """
    Rebuild retriever + LLM pipeline after adding new documents.
    """
    global retriever, llm

    if vector_store is None:
        return

    retriever = vector_store.as_retriever(
        search_kwargs={"k": Config.TOP_K}
    )

    if llm is None:
        if not Config.GROQ_API_KEY:
            raise RuntimeError("GROQ_API_KEY is not set in environment.")
        llm = ChatGroq(
            groq_api_key=Config.GROQ_API_KEY,
            model_name=Config.MODEL_NAME,
            temperature=0.2,
        )


def init_system():
    global vector_store, llm

    embeddings = HuggingFaceEmbeddings(
        model_name=Config.EMBEDDING_MODEL
    )

    vector_store = Chroma(
        persist_directory=Config.CHROMA_PATH,
        collection_name="knowledgebase",
        embedding_function=embeddings,
    )

    # Initialize LLM once
    if Config.GROQ_API_KEY:
        llm = ChatGroq(
            groq_api_key=Config.GROQ_API_KEY,
            model_name=Config.MODEL_NAME,
            temperature=0.2,
        )

    if vector_store._collection.count() > 0:
        rebuild_rag()
        print("✅ Knowledge base loaded.")
    else:
        print("⚠️ Knowledge base empty — upload PDFs.")


@app.on_event("startup")
async def startup():
    init_system()


# ================================
# MODELS
# ================================
class Query(BaseModel):
    query: str


# ================================
# HEALTH CHECK
# ================================
@app.get("/")
async def root():
    return {"status": "ok", "message": "RAG backend is running."}


@app.get("/health")
async def health():
    return {"status": "ok"}


# ================================
# UPLOAD PDF
# ================================
@app.post("/upload-pdf")
async def upload_pdf(file: UploadFile = File(...)):
    global vector_store

    if vector_store is None:
        raise HTTPException(500, "Vector store is not initialized.")

    tmp_path = f"temp_{file.filename}"

    try:
        with open(tmp_path, "wb") as f:
            shutil.copyfileobj(file.file, f)

        loader = PyPDFLoader(tmp_path)
        pages = loader.load()

        # add source metadata so we can show file names later
        for p in pages:
            p.metadata["source"] = file.filename

        splitter = RecursiveCharacterTextSplitter(
            chunk_size=Config.CHUNK_SIZE,
            chunk_overlap=Config.CHUNK_OVERLAP,
        )

        chunks = splitter.split_documents(pages)
        vector_store.add_documents(chunks)

        # re-create retriever after adding new docs
        rebuild_rag()

        return {"status": "ok", "message": f"PDF '{file.filename}' added."}

    except Exception as e:
        print("❌ Error while processing PDF:", e)
        raise HTTPException(500, f"Failed to process PDF: {e}")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


# ================================
# ASK (Flutter-compatible)
# ================================
@app.post("/ask")
async def ask(req: Query):
    global chat_history, retriever, llm

    if retriever is None or llm is None:
        raise HTTPException(400, "Knowledge base is empty or LLM not initialized.")

    user_question = req.query

    # 1. Build simple text-based history (optional)
    history_text = ""
    for msg in chat_history:
        if isinstance(msg, HumanMessage):
            history_text += f"Human: {msg.content}\n"
        elif isinstance(msg, AIMessage):
            history_text += f"AI: {msg.content}\n"

    # 2. Use ONLY current question for retrieval
    docs = retriever.get_relevant_documents(user_question)
    context = "\n\n".join(doc.page_content for doc in docs[: Config.TOP_K])

    # 3. Build prompt with context + history
    system_prompt = (
        "You are a helpful learning assistant for an e-learning system.\n"
        "Always answer clearly and step-by-step.\n"
        "Use the following context if it is relevant:\n\n"
        f"{context}\n\n"
        "If the context is not helpful, answer from your own knowledge."
    )

    messages = [
        HumanMessage(content=system_prompt),
        HumanMessage(content=f"Conversation so far:\n{history_text}"),
        HumanMessage(content=f"User question: {user_question}"),
    ]

    try:
        response = llm.invoke(messages)
        answer = response.content
    except Exception as e:
        print("❌ Error while generating answer:", e)
        raise HTTPException(500, "Failed to generate answer")

    # 4. Update memory
    chat_history.append(HumanMessage(content=user_question))
    chat_history.append(AIMessage(content=answer))

    # 5. Collect simple source filenames (for UI, optional)
    sources = []
    for d in docs:
        src = d.metadata.get("source")
        if src and src not in sources:
            sources.append(src)

    return {
        "answer": answer,
        "sources": sources,  # Flutter can ignore if not needed
    }


# ================================
# RESET MEMORY
# ================================
@app.post("/reset")
async def reset():
    chat_history.clear()
    return {"status": "cleared"}


# ================================
# RUN (Railway)
# ================================
if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)