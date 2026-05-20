"""
CONVERSATIONAL CHATBOT WITH NATURAL INFO COLLECTION
Bot Name: Alex (Friendly AI Assistant)
Strategy: Collect user info naturally through conversation, not as a form
"""

import pandas as pd
import numpy as np
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from fuzzywuzzy import fuzz
import random

file_path = r"C:\Users\LENOVO\Desktop\psql\studentproject\chat_bot\data.csv"

def preprocess_text(text):
    text = str(text).lower()
    text = re.sub(r'[^a-zA-Z0-9 @.]', '', text)
    return text.strip()

df = pd.read_csv(file_path)
df['Question_cleaned'] = df['Question'].apply(preprocess_text)

vectorizer = TfidfVectorizer(ngram_range=(1, 2))
tfidf_matrix = vectorizer.fit_transform(df['Question_cleaned'])

conversation_memory = {}

def is_email(text):
    pattern = r'^[\w\.-]+@[\w\.-]+\.\w+$'
    return bool(re.match(pattern, text.strip()))

def is_phone(text):
    digits = ''.join(filter(str.isdigit, text))
    return len(digits) >= 10

def is_name(text):
    """Check if text looks like a name (2-30 chars, mostly letters)"""
    cleaned = re.sub(r'[^a-zA-Z\s]', '', text).strip()
    return len(cleaned.split()) <= 3 and len(cleaned) >= 2 and len(cleaned) <= 50

class ConversationalChatBot:
    """
    Alex - The Friendly Chatbot
    Collects user info naturally during conversation
    """
    def __init__(self, threshold=0.3):
        self.threshold = threshold
        self.questions_list = df['Question_cleaned'].tolist()
        self.answers_list = df['Answer'].tolist()
        self.bot_name = "Alex"
        
        # Greeting responses to feel more human
        self.greetings = [
            "Hey there! 👋 What's up?",
            "Hi! Excited to help you out today! 😊",
            "Hello! How's it going?",
            "Hey! What can I do for you?",
            "Heya! What brings you here?"
        ]

    def faq_response(self, user_input):
        """Find best matching answer from FAQ database"""
        user_cleaned = preprocess_text(user_input)
        if not user_cleaned:
            return "I didn't quite catch that. Can you say it again?"

        user_tfidf = vectorizer.transform([user_cleaned])
        tfidf_similarities = cosine_similarity(user_tfidf, tfidf_matrix)[0]
        combined_scores = []

        for i, question in enumerate(self.questions_list):
            fuzzy_ratio = fuzz.ratio(user_cleaned, question) / 100.0
            token_set_ratio = fuzz.token_set_ratio(user_cleaned, question) / 100.0
            best_fuzzy = max(fuzzy_ratio, token_set_ratio)
            combined_score = (tfidf_similarities[i] * 0.5) + (best_fuzzy * 0.5)
            combined_scores.append(combined_score)

        best_match_idx = np.argmax(combined_scores)
        best_score = combined_scores[best_match_idx]

        if best_score < self.threshold:
            return "Hmm, I'm not sure about that one. Could you rephrase it differently?"

        return self.answers_list[best_match_idx]

    def handle_name_input(self, session_id, msg):
        """Process name when user is in name-collection mode"""
        user = conversation_memory[session_id]
        lower_msg = msg.lower()

        # If user explicitly declines to share name, return the last saved answer (if any)
        if lower_msg in ['no', 'skip', 'nope', 'not now', 'not interested', 'later']:
            user['name'] = None
            user['step'] = 'normal'
            if user.get('last_faq_answer'):
                return f"No problem. Here's the answer to your question:\n\n{user['last_faq_answer']}"
            return "No problem! So what would you like to ask?"

        # Accept any input as name (2-50 chars)
        if msg.strip() and 2 <= len(msg.strip()) <= 50:
            user['name'] = msg.strip()
            user['step'] = 'normal'
            
            # If we have a saved question, answer it now along with the name
            if user.get('last_faq_answer'):
                responses = [
                    f"Thanks {msg}! 👋 So here's what I found:\n\n{user['last_faq_answer']}",
                    f"Nice to meet you, {msg}! Here's the answer:\n\n{user['last_faq_answer']}",
                    f"Great {msg}! Here's what I can tell you:\n\n{user['last_faq_answer']}",
                    f"Thanks for that, {msg}! Here's the info you asked for:\n\n{user['last_faq_answer']}"
                ]
            else:
                responses = [
                    f"Thanks {msg}! 👋 So what can I help you with today?",
                    f"Nice to meet you, {msg}! What would you like to know?",
                    f"Great {msg}! What brings you here?",
                    f"Thanks for that, {msg}! What do you need help with?"
                ]
            return random.choice(responses)

        # Only ask once - then accept or move on anyway
        if user.get('name_ask_count', 0) == 0:
            user['name_ask_count'] = 1
            return "What's your name? 😊"
        else:
            # After asking once, accept whatever they say
            user['name'] = msg.strip() if msg.strip() else 'Friend'
            user['step'] = 'normal'
            
            # If we have a saved question, answer it now
            if user.get('last_faq_answer'):
                return f"Thanks! Here's your answer:\n\n{user['last_faq_answer']}"
            return f"Thanks! So what would you like to ask?"

    def handle_email_input(self, session_id, msg):
        """Process email when user is in email-collection mode"""
        user = conversation_memory[session_id]
        lower_msg = msg.lower()
        
        # If user declines, answer the last question (if any) and move on
        if lower_msg in ['no', 'skip', 'nope', 'not now', 'not interested', 'later']:
            user['email'] = None
            user['step'] = 'normal'
            if user.get('last_faq_answer'):
                return f"No worries. Here's the answer to your question:\n\n{user['last_faq_answer']}"
            return "No problem! So what would you like to ask me?"
        
        # Accept any non-empty answer as email (even if format isn't perfect)
        # More forgiving than strict validation
        if msg.strip() and len(msg.strip()) > 3:
            user['email'] = msg.strip()
            user['step'] = 'normal'
            
            # Build email benefit message
            email_benefits = f"""Perfect! I've got {msg.strip()} saved 📧

With your email, I can send you:
✨ Exclusive course details
🎁 Special offers and discounts  
📚 Latest admission updates
🎯 Personalized program recommendations
💼 Career guidance tips"""
            
            # If we have a saved question, answer it after email benefits
            if user.get('last_faq_answer'):
                response = f"{email_benefits}\n\nNow, here's the answer to your question:\n{user['last_faq_answer']}"
            else:
                response = f"{email_benefits}\n\nSo what else would you like to know?"
            
            return response
        
        # Only ask once - then move forward anyway
        if user.get('email_ask_count', 0) == 0:
            user['email_ask_count'] = 1
            return "Can you double-check that for me? Or just type 'no' if you'd rather not share."
        else:
            # After one attempt, accept whatever they say or move on
            user['email'] = msg.strip() if msg.strip() else None
            user['step'] = 'normal'
            
            if user.get('last_faq_answer'):
                return f"No worries! Here's your answer:\n\n{user['last_faq_answer']}"
            return "No worries! So what would you like to know?"

    def handle_phone_input(self, session_id, msg):
        """Process phone when user is in phone-collection mode"""
        user = conversation_memory[session_id]
        lower_msg = msg.lower()
        
        # If user declines phone, answer last question if available
        if lower_msg in ['no', 'skip', 'nope', 'not now', 'not interested', 'later']:
            user['phone'] = None
            user['status'] = 'interested'
            user['step'] = 'normal'
            if user.get('last_faq_answer'):
                return f"No worries. Here's the answer to your question:\n\n{user['last_faq_answer']}"
            return "All set! So what would you like to ask me?"
        
        # Accept any input with at least 5+ digits as phone (more forgiving)
        digits = ''.join(filter(str.isdigit, msg))
        if len(digits) >= 5:
            user['phone'] = msg.strip()
            user['status'] = 'interested'
            user['step'] = 'normal'
            
            # Build phone benefit message
            phone_benefits = f"""Perfect! I've got {msg.strip()} saved 📱

Now we can:
📞 Call you for exclusive updates
✨ Send you SMS alerts for new courses
🎁 Notify you about special offers
💼 Reach out with career opportunities"""
            
            # If we have a saved question, answer it after phone benefits
            if user.get('last_faq_answer'):
                response = f"{phone_benefits}\n\nNow, here's the answer to your question:\n{user['last_faq_answer']}"
            else:
                response = f"{phone_benefits}\n\nSo what else can I help with?"
            
            return response
        
        # Only ask once - then move forward anyway
        if user.get('phone_ask_count', 0) == 0:
            user['phone_ask_count'] = 1
            return "That doesn't look quite right. Can you try again? (Or type 'no')"
        else:
            # After one attempt, accept or skip
            user['phone'] = msg.strip() if msg.strip() else None
            user['status'] = 'interested'
            user['step'] = 'normal'
            
            if user.get('last_faq_answer'):
                return f"No worries! Here's your answer:\n\n{user['last_faq_answer']}"
            return "No worries! What would you like to ask me?"

    def should_ask_for_name(self, user):
        """Decide if it's time to ask for name - after 2-3 messages and natural interaction"""
        return (
            not user['name'] and 
            user['count'] >= 2 and
            user['count'] <= 5 and
            random.random() > 0.4  # 60% chance to ask
        )

    def should_ask_for_email(self, user):
        """Decide if it's time to ask for email - after a few exchanges and has name"""
        return (
            user['name'] and 
            not user['email'] and 
            user['count'] >= 5 and
            user['count'] <= 10 and
            user['status'] != 'skipped' and
            random.random() > 0.5  # 50% chance to ask
        )

    def should_ask_for_phone(self, user):
        """Decide if it's time to ask for phone - after email and more interaction"""
        return (
            user['email'] and 
            not user['phone'] and 
            user['count'] >= 8 and
            user['status'] != 'skipped' and
            random.random() > 0.6  # 40% chance to ask
        )

    def get_response(self, session_id, user_input):
        """Main chatbot logic - conversational and smart"""
        if session_id not in conversation_memory:
            conversation_memory[session_id] = {
                'count': 0,
                'name': None,
                'email': None,
                'phone': None,
                'status': 'pending',
                'step': 'normal',
                'messages_since_name_ask': 0,
                'messages_since_email_ask': 0,
                'last_question': None,  # Store user's question before asking for name
                'last_faq_answer': None  # Store answer to deliver with name response
            }

        user = conversation_memory[session_id]
        user['count'] += 1
        msg = user_input.strip()
        lower_msg = msg.lower()

        # Handle active steps (user is responding to a question)
        if user['step'] == 'ask_name':
            return self.handle_name_input(session_id, msg)
        
        if user['step'] == 'ask_email':
            return self.handle_email_input(session_id, msg)
        
        if user['step'] == 'ask_phone':
            return self.handle_phone_input(session_id, msg)

        # Get FAQ answer first (save it in case we need it after name collection)
        faq_answer = self.faq_response(msg)
        user['last_question'] = msg
        user['last_faq_answer'] = faq_answer

        # Natural conversation: Gradually collect info
        if self.should_ask_for_name(user):
            user['step'] = 'ask_name'
            natural_asks = [
                "Sorry for interrupting 😊 What is your name, so I can call you by your name too?",
                "Sorry to interrupt — what should I call you?",
                "Sorry, may I know your name so I can address you properly?",
                "Sorry for asking in between 👋 Who am I chatting with?",
                "Sorry 😊 Can I know your name?"
            ]
            return random.choice(natural_asks)
        
        if self.should_ask_for_email(user):
            user['step'] = 'ask_email'
            natural_asks = natural_asks = [
                f"Sorry for asking, {user['name']} 😊📧 If you share your email, we can send more offers 🎁, course details 📚, and useful updates ✨ through your email. Would you like to share it?",
                
                f"Sorry to interrupt, {user['name']} 🙏📩 If you provide your email, we can send updates 🔔, special offers 🎉, and course information 📘 to your email. Or just type 'no' 😊",
                
                f"Sorry {user['name']} 😊📬 If you give your email address, we can share more course details 📖, upcoming offers 🎁, and important notifications 🔔 through email."
            ]
            return random.choice(natural_asks)
        
        if self.should_ask_for_phone(user):
            user['step'] = 'ask_phone'
            natural_asks = natural_asks = [
                f"Sorry for asking, {user['name']} 😊📱 If you'd like, you can share your phone number so we can contact you for course support 📚, updates 🔔, or quick follow-up calls ☎️.",
                
                f"Sorry to interrupt, {user['name']} 🙏📞 If you share your phone number, we can reach you for important updates ✨, offers 🎁, and course-related help. Or just type 'no' 😊",
                
                f"Sorry {user['name']} 📱😊 Would you like to share your phone number? We can use it to contact you for follow-up support 🤝 and important notifications 🔔."
            ]
            return random.choice(natural_asks)

        # Personalize responses with name if we have it
        if user['name']:
            personalized = [
                f"{user['name']}: {faq_answer}",
                f"{faq_answer} Hope that helps, {user['name']}!",
                faq_answer  # Sometimes don't add name to feel natural
            ]
            return random.choice(personalized)
        
        return faq_answer

chatbot = ConversationalChatBot()

def get_chat_response(session_id, message):
    """Public API - called from views.py"""
    return chatbot.get_response(session_id, message)

