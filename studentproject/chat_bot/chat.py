



import pandas as pd
import numpy as np
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from fuzzywuzzy import fuzz

# EXPLICITLY DEFINE THIS GLOBAL VARIABLE FOR THE VIEWS APP TO READ
file_path = r"C:\Users\LENOVO\Desktop\psql\studentproject\chat_bot\data.csv"

def preprocess_text(text):
    text = str(text).lower()
    text = re.sub(r'[^a-zA-Z0-9 ]', '', text)
    return text.strip()

# Load data using that file path
df = pd.read_csv(file_path)
#data ser quetsion is cleaned and stored in the new column "Question_cleaned"
df['Question_cleaned'] = df['Question'].apply(preprocess_text)


# This converts all CSV questions into mathematical vectors.
# Machine compares numbers instead of words.
#each word na number akii mattum... what is attendance in to [0.3, 0.5, 0.8]
vectorizer = TfidfVectorizer(ngram_range=(1, 2))  # here numbers is tere so it can handle one word and 2 word combination. so accurcy will increase.. 
#This converts all CSV questions into vectors. and store into tfidf_matrix
tfidf_matrix = vectorizer.fit_transform(df['Question_cleaned'])

class ChatBot:
    def __init__(self, threshold=0.3): # 0.3 means 30 % its bellow vana it say not unserastand
        self.threshold = threshold
        self.questions_list = df['Question_cleaned'].tolist()
        self.answers_list = df['Answer'].tolist()
        



    def get_response(self, user_input):
        #frontend nu response vazhi user questionna filter ceyum... 
        user_cleaned = preprocess_text(user_input)
        if not user_cleaned:
            return "Please type something so I can help you!"

#user question is converted in to numbers. . 
        user_tfidf = vectorizer.transform([user_cleaned])
        #data set questions and user question are compared using cosine similarity. . 
        #before we convert the user question into numbers we clean the question 
        # and then we convert it into numbers 
        # and then we compare the user question .. user question also converted into numbers.. with the data set questions using cosine similarity. .
        # after combaining higest value will take..
        tfidf_similarities = cosine_similarity(user_tfidf, tfidf_matrix)[0]

        combined_scores = []

        #fuzzy will handle similar words like: user enter aple into corrcet word apple
        for i, question in enumerate(self.questions_list):
            fuzzy_ratio = fuzz.ratio(user_cleaned, question) / 100.0
            token_set_ratio = fuzz.token_set_ratio(user_cleaned, question) / 100.0
            best_fuzzy = max(fuzzy_ratio, token_set_ratio)
            
            combined_score = (tfidf_similarities[i] * 0.5) + (best_fuzzy * 0.5)
            combined_scores.append(combined_score)

        best_match_idx = np.argmax(combined_scores)
        best_score = combined_scores[best_match_idx]

        if best_score < self.threshold:
            return "I'm sorry, I didn't understand. Can you rephrase your question?"


# best anser and find ceyutu view.py ku sent ceyum...
        return self.answers_list[best_match_idx]

# Create global chatbot instance
chatbot = ChatBot()

def get_chat_response(message):
    """Wrapper function for Django views"""
    return chatbot.get_response(message)