import { useEffect, useRef, useState } from 'react';
import './ChatBot.css';

const ChatBot = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [inputValue, setInputValue] = useState('');
  const [messages, setMessages] = useState([
    {
      role: 'bot',
      text: "Hello! I'm your student assistant. How can I help you today?",
    },
  ]);
  const [sessionId, setSessionId] = useState('');
  const messagesEndRef = useRef(null);

  useEffect(() => {
    let storedSessionId = localStorage.getItem('chatSessionId');
    if (!storedSessionId) {
      storedSessionId = `session_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
      localStorage.setItem('chatSessionId', storedSessionId);
    }
    setSessionId(storedSessionId);
  }, []);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const getCookie = (name) => {
    const cookies = document.cookie ? document.cookie.split(';') : [];
    for (let cookie of cookies) {
      cookie = cookie.trim();
      if (cookie.startsWith(`${name}=`)) {
        return decodeURIComponent(cookie.substring(name.length + 1));
      }
    }
    return null;
  };

  const addMessage = (text, role = 'bot') => {
    setMessages((current) => [...current, { role, text }]);
  };

  const sendMessage = async () => {
    const message = inputValue.trim();
    if (!message) return;

    addMessage(message, 'user');
    setInputValue('');
    addMessage('Typing...', 'typing');

    try {
      const response = await fetch('/chat_bot/api/send/', {
        method: 'POST',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRFToken': getCookie('csrftoken'),
        },
        body: JSON.stringify({ message, session_id: sessionId }),
      });

      const data = await response.json();
      setMessages((current) => current.filter((msg) => msg.role !== 'typing'));

      if (data.success) {
        addMessage(data.response, 'bot');
      } else {
        addMessage("Sorry, I'm having trouble. Please try again.", 'bot');
      }
    } catch (error) {
      setMessages((current) => current.filter((msg) => msg.role !== 'typing'));
      addMessage('Network error. Please check your connection.', 'bot');
    }
  };

  const handleInputKeyDown = (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="chatbot-page">
      <div className="chatbot-widget">
        <button className="chatbot-toggle" onClick={() => setIsOpen((prev) => !prev)}>
          💬
        </button>

        <div className={`chatbot-window ${isOpen ? 'open' : ''}`}>
          <div className="chatbot-header">
            <h3>🤖 Student Assistant</h3>
            <button className="chatbot-close" onClick={() => setIsOpen(false)}>
              ×
            </button>
          </div>

          <div className="chatbot-stats">
            <span>📚 ^_^. . Haiii</span>
            <span>💡 Ask me anything!</span>
          </div>

          <div className="chatbot-messages">
            {messages.map((message, index) => (
              <div
                key={`${message.role}-${index}`}
                className={`chat-message ${message.role === 'user' ? 'user' : message.role === 'typing' ? 'bot' : 'bot'}`}
              >
                <div className="message-bubble">
                  {message.role === 'typing' ? (
                    <div className="typing-indicator">
                      <span></span>
                      <span></span>
                      <span></span>
                    </div>
                  ) : (
                    <>{message.text}</>
                  )}
                  {message.role !== 'typing' && <div className="message-time">{new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>}
                </div>
              </div>
            ))}
            <div ref={messagesEndRef} />
          </div>

          <div className="chatbot-input-area">
            <input
              value={inputValue}
              onChange={(event) => setInputValue(event.target.value)}
              onKeyDown={handleInputKeyDown}
              className="chatbot-input"
              placeholder="Type your message..."
              autoComplete="off"
            />
            <button className="chatbot-send" onClick={sendMessage}>
              ➤
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ChatBot;
