import PyPDF2
import io
from typing import List


class PDFProcessor:
    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 200):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def process_pdf(self, pdf_file) -> List[str]:
        """Extract text from PDF and split into chunks"""
        try:
            # Read PDF
            pdf_reader = PyPDF2.PdfReader(pdf_file)
            text = ""

            for page in pdf_reader.pages:
                text += page.extract_text() + "\n"

            # Simple text splitting (can be enhanced with LangChain later)
            chunks = self._split_text(text)
            return chunks

        except Exception as e:
            print(f"Error processing PDF: {e}")
            return []

    def _split_text(self, text: str) -> List[str]:
        """Split text into overlapping chunks"""
        words = text.split()
        chunks = []

        for i in range(0, len(words), self.chunk_size - self.chunk_overlap):
            chunk = " ".join(words[i:i + self.chunk_size])
            chunks.append(chunk)

            if i + self.chunk_size >= len(words):
                break

        return chunks