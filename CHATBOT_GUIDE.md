# 🤖 Conversational Chatbot Guide - "Alex"

## Overview
**Alex** is your friendly chatbot that collects user information naturally during conversation—NOT like a form. It feels like chatting with a real person.

---

## 🎯 How It Works

### Key Features

1. **Natural Conversation Flow**
   - Questions are asked at the right time (not all at once)
   - Bot responds with FAQ answers first, then gradually asks for info
   - Messages personalize based on what the user shares

2. **Gentle Information Collection**
   - **Name** - Asked after 2-3 natural messages
   - **Email** - Asked after 5-10 messages if user seems engaged
   - **Phone** - Asked only if email was provided
   - **No pressure** - User can skip any step by typing "no", "skip", or "later"

3. **Data Storage**
   - Data only saved if user shares it willingly
   - Stored in `chatbot_user_details` table with session tracking
   - If user declines, chatbot still works perfectly as normal AI

4. **Three Conversation Modes**
   ```
   NORMAL MODE → User chats normally (no data collection attempt)
               ↓ (After 2-3 messages)
   ASK_NAME   → Bot asks "What's your name?" 
               ↓ (User provides name or says "no")
   NORMAL MODE → Continues with FAQ answers
               ↓ (After 5-10 messages)
   ASK_EMAIL  → Bot asks "Want to share your email?"
               ↓ (User provides email or says "no")
   NORMAL MODE → Can continue asking
               ↓ (If email provided + more messages)
   ASK_PHONE  → Bot asks "Got a phone number to save?"
               ↓ (User provides phone or says "no")
   NORMAL MODE → Works forever as normal chatbot
   ```

---

## 💬 Sample Conversation

```
User: Hi
Alex: Hey there! 👋 What's up?

User: I want to know about admissions
Alex: [FAQ Answer about admissions]

User: That's great!
Alex: By the way, I'd love to know - what's your name? 😊

User: My name is John
Alex: Nice to meet you, John! 👋

User: Can I get more info?
Alex: [FAQ Answer]
Alex: Hope that helps, John!

User: Yes very helpful
Alex: John, if you'd like me to send you updates or helpful info, I can use your email. What's best for you?

User: Sure! john@example.com
Alex: Got it! I'll keep john@example.com on file. We can send you updates there.

User: What else can you help with?
Alex: [FAQ Answer]

User: One more question
Alex: One more thing, John - if you want us to call you, what's the best number to reach you? 📱

User: It's 9876543210
Alex: Thanks! Got your number saved. We can reach you if needed! 📱

User: Great, thanks!
Alex: You're welcome! Feel free to ask me anything. 😊
```

---

## 📊 Database Structure

### chatbot_user_details Table

```sql
CREATE TABLE chatbot_user_details (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(200) UNIQUE,           -- Unique session per user
    name VARCHAR(150),                        -- User's name (optional)
    email VARCHAR(200),                       -- User's email (optional)
    phone VARCHAR(20),                        -- User's phone (optional)
    status VARCHAR(50),                       -- 'interested', 'skipped', 'pending'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Status Values
- `interested` - User shared at least name or email
- `skipped` - User explicitly declined to share
- `pending` - Still in conversation, not yet shared

---

## 🔧 Configuration

### Timing of Info Requests (in `chat.py`)

Adjust these methods to change when Alex asks for info:

```python
def should_ask_for_name(self, user):
    # Asks after 2-5 messages, 60% chance
    return (
        not user['name'] and 
        user['count'] >= 2 and
        user['count'] <= 5 and
        random.random() > 0.4
    )

def should_ask_for_email(self, user):
    # Asks after 5-10 messages with name, 50% chance
    return (
        user['name'] and 
        not user['email'] and 
        user['count'] >= 5 and
        user['count'] <= 10 and
        random.random() > 0.5
    )

def should_ask_for_phone(self, user):
    # Asks after 8+ messages with email, 40% chance
    return (
        user['email'] and 
        not user['phone'] and 
        user['count'] >= 8 and
        random.random() > 0.6
    )
```

### Adjust These Values:
- `user['count'] >= X` - Min messages before asking
- `user['count'] <= X` - Max messages before asking (to avoid too late)
- `random.random() > X` - Probability (0.4 = 60% chance, 0.5 = 50% chance)

---

## 🎨 Customizing Responses

In `chat.py`, you can modify:

### Greeting Messages
```python
self.greetings = [
    "Hey there! 👋 What's up?",
    "Hi! Excited to help you out today! 😊",
    # Add your own...
]
```

### Name Request Messages
```python
natural_asks = [
    "By the way, I'd love to know - what's your name? 😊",
    "Hey, what should I call you?",
    # Add your own...
]
```

### Email Request Messages
```python
natural_asks = [
    f"{user['name']}, if you'd like me to send you updates...",
    # Add your own...
]
```

Similarly for phone and other interactions.

---

## 🚀 How to Deploy

1. **Database Migration** (if needed)
   ```bash
   python manage.py makemigrations chat_bot
   python manage.py migrate
   ```

2. **Restart Django Server**
   ```bash
   python manage.py runserver
   ```

3. **Test the Chatbot**
   - Open the chatbot interface
   - Start a conversation
   - See how Alex naturally collects information

---

## 📈 Monitoring

### Check Collected Data
```sql
-- All users who shared info
SELECT * FROM chatbot_user_details WHERE status='interested';

-- How many sessions total
SELECT COUNT(*) FROM chatbot_user_details;

-- Recent interactions
SELECT * FROM chatbot_user_details ORDER BY created_at DESC LIMIT 10;
```

---

## ⚠️ Important Notes

1. **If User Says "No"**
   - Bot gracefully skips that step
   - Continues as normal chatbot
   - No pressure or nagging

2. **Data Privacy**
   - Only stores what user voluntarily shares
   - Session-based (no account required)
   - Can be deleted anytime

3. **FAQ System Still Works**
   - Alex answers from your CSV data first
   - Information collection is secondary
   - User can ignore collection and just ask questions

4. **Real Person Feel**
   - Random responses to avoid repetition
   - Personalized with user's name
   - Natural transition between FAQ and info collection

---

## 🎯 Files Modified

1. **`chat_bot/chat.py`** - Conversational logic (ConversationalChatBot class)
2. **`chat_bot/views.py`** - API and database saving
3. **`chat_bot/models.py`** - Django model for user data

---

## 💡 Tips

- **For More Aggressive Collection**: Reduce random thresholds (e.g., 0.3 instead of 0.4)
- **For Less Aggressive**: Increase random thresholds (e.g., 0.7 instead of 0.6)
- **For Different Bot Personality**: Add more varied response options
- **For Mobile Users**: Test on phone to ensure button clicks work

---

## 🤝 Support

If you need to:
- Change question timing → Modify `should_ask_for_*` methods
- Add new fields → Update database table + chat.py + models.py
- Change bot name → Replace "Alex" in `chat.py`
- Add new greeting style → Add to `self.greetings` list

---

**Built with ❤️ for natural, friendly conversations!**
