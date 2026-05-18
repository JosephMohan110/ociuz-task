import pandas as pd
import numpy as np
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Define the function structure for Django
def preprocess_text(text):
    text = str(text).lower()
    text = re.sub(r'[^a-zA-Z0-9 ]', '', text)
    return text

# Load and process data
file_path = r"C:\Users\LENOVO\Desktop\psql\studentproject\chat_bot\data.csv"
df = pd.read_csv(file_path)
df['Question'] = df['Question'].apply(preprocess_text)

vectorizer = TfidfVectorizer()
tfidf_matrix = vectorizer.fit_transform(df['Question'])

class ChatBot:
    def __init__(self, threshold=0.2):
        self.threshold = threshold
        
    def get_response(self, user_input):
        user_input = preprocess_text(user_input)
        user_tfidf = vectorizer.transform([user_input])
        similarities = cosine_similarity(user_tfidf, tfidf_matrix)

        best_match_idx = np.argmax(similarities)
        best_score = similarities[0, best_match_idx]

        if best_score < self.threshold:
            return "I'm sorry, I didn't understand. Can you rephrase your question?"

        return df.iloc[best_match_idx]['Answer']

# Create a global chatbot instance
chatbot = ChatBot()

def get_chat_response(message):
    """Wrapper function for Django views"""
    return chatbot.get_response(message)
