"""
Quick Test Script for BiLSTM NER Model

This script helps you verify that your trained model is working correctly
and not suffering from the "all O tags" problem.
"""

import numpy as np
import json
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.sequence import pad_sequences
import re

# ==========================================
# CONFIGURATION
# ==========================================

MODEL_PATH = 'sms_ner_bilstm_model.h5'
WORD_TOKENIZER_PATH = 'word_tokenizer_bilstm.json'
TAG_TOKENIZER_PATH = 'tag_tokenizer_bilstm.json'
MAX_LEN = 75

# ==========================================
# TEST MESSAGES
# ==========================================

TEST_MESSAGES = [
    # HDFC Format
    "Sent Rs.125.00 From HDFC Bank A/C *4862 To MC DONALDS On 17/10/25",
    
    # ICICI Format
    "ICICI Bank Acct XX924 debited for Rs 4000.00 on 20-Jan-24; Prajakta Rajend credited. UPI:402066880262",
    
    # SBI Format
    "Dear UPI user A/C X5929 debited by 125.0 on date 01Aug25 trf to HANUMAN SUPER MA Refno 182971619477.",
    
    # IPPB Format
    "A/C X5499 Debit Rs.500.00 for UPI to harsh panduran on 16-10-25 Ref 528978458683.",
    
    # Cosmos Format
    "Your Alc XX7030 is debited by INR 220 on 13-05-2025 for MSEDCL-160220725411.",
    
    # Credit Transaction
    "Credit Alert! Rs.500.00 credited to HDFC Bank A/c XX4862 on 16-10-25 from VPA harshofficial654-1@okaxis",
]

# ==========================================
# HELPER FUNCTIONS
# ==========================================

def normalize_token(token):
    """Normalize token similar to training"""
    token = token.lower().strip()
    token = re.sub(r'[^a-z0-9\.\*@]', '', token)
    return token

def tokenize_text(text):
    """Tokenize text similar to training"""
    text = text.lower().replace('\n', ' ').replace('\r', ' ')
    text = re.sub(r'\s+', ' ', text).strip()
    
    raw_tokens = text.split()
    tokens = []
    
    for token in raw_tokens:
        sub_tokens = re.split(r'(\W+)', token)
        for sub in sub_tokens:
            normalized = normalize_token(sub)
            if normalized:
                tokens.append(normalized)
    
    return tokens

def extract_entities(tokens, tags):
    """Extract entities from IOB tags"""
    entities = {
        'merchant': [],
        'amount': [],
        'bank': []
    }
    
    buffer = []
    current_entity = None
    
    for token, tag in zip(tokens, tags):
        if tag.startswith('B-'):
            # Save previous entity
            if buffer and current_entity:
                entity_text = ' '.join(buffer)
                entities[current_entity.lower()].append(entity_text)
            
            # Start new entity
            current_entity = tag[2:]  # Remove 'B-'
            buffer = [token]
        
        elif tag.startswith('I-'):
            # Continue entity
            if current_entity:
                buffer.append(token)
        
        else:  # 'O' tag
            # Save previous entity
            if buffer and current_entity:
                entity_text = ' '.join(buffer)
                entities[current_entity.lower()].append(entity_text)
            
            buffer = []
            current_entity = None
    
    # Save final entity
    if buffer and current_entity:
        entity_text = ' '.join(buffer)
        entities[current_entity.lower()].append(entity_text)
    
    return entities

# ==========================================
# MAIN TEST
# ==========================================

def main():
    print(f"\n{'='*70}")
    print("🧪 BiLSTM NER Model Testing")
    print(f"{'='*70}\n")
    
    # Load model
    print("📦 Loading model...")
    try:
        model = load_model(MODEL_PATH, compile=False)
        print(f"   ✓ Loaded model from {MODEL_PATH}")
    except Exception as e:
        print(f"   ❌ Error loading model: {e}")
        print(f"   Make sure you've run train_bilstm_ner.py first!")
        return
    
    # Load word tokenizer
    print("\n📦 Loading tokenizers...")
    with open(WORD_TOKENIZER_PATH) as f:
        word_data = json.load(f)
        index_word = word_data['config']['index_word']
        word2idx = {word: int(idx) for idx, word in index_word.items()}
        print(f"   ✓ Loaded word tokenizer ({len(word2idx)} words)")
    
    # Load tag tokenizer
    with open(TAG_TOKENIZER_PATH) as f:
        tag_data = json.load(f)
        idx2tag = {int(k): v for k, v in tag_data['idx2tag'].items()}
        print(f"   ✓ Loaded tag tokenizer ({len(idx2tag)} tags)")
    
    # Test each message
    print(f"\n{'='*70}")
    print("🔍 Testing Messages")
    print(f"{'='*70}\n")
    
    total_entity_predictions = 0
    total_predictions = 0
    
    for i, sms in enumerate(TEST_MESSAGES, 1):
        print(f"\n{'─'*70}")
        print(f"Test {i}:")
        print(f"{'─'*70}")
        print(f"SMS: {sms}\n")
        
        # Tokenize
        tokens = tokenize_text(sms)
        
        # Encode
        sequence = [word2idx.get(token, word2idx.get('<OOV>', 1)) for token in tokens]
        padded = pad_sequences([sequence], maxlen=MAX_LEN, padding='post', value=0)
        
        # Predict
        predictions = model.predict(padded, verbose=0)
        predicted_tag_indices = np.argmax(predictions[0], axis=-1)
        
        # Decode tags
        predicted_tags = [idx2tag.get(idx, 'O') for idx in predicted_tag_indices[:len(tokens)]]
        
        # Count entity predictions
        entity_count = sum(1 for tag in predicted_tags if tag != 'O')
        total_entity_predictions += entity_count
        total_predictions += len(tokens)
        
        # Extract entities
        entities = extract_entities(tokens, predicted_tags)
        
        # Display
        print(f"{'Token':<25} {'Tag':<15} {'Confidence'}")
        print(f"{'-'*70}")
        for j, (token, tag_idx) in enumerate(zip(tokens, predicted_tag_indices[:len(tokens)])):
            tag = idx2tag.get(tag_idx, 'O')
            confidence = predictions[0][j][tag_idx]
            
            # Color coding
            if tag.startswith('B-'):
                marker = '→'
            elif tag.startswith('I-'):
                marker = '  →'
            else:
                marker = ''
            
            print(f"{marker} {token:<23} {tag:<15} {confidence:.4f}")
        
        # Display extracted entities
        print(f"\n📋 Extracted Entities:")
        print(f"   💰 Amount:   {', '.join(entities['amount']) if entities['amount'] else 'None'}")
        print(f"   🏪 Merchant: {', '.join(entities['merchant']) if entities['merchant'] else 'None'}")
        print(f"   🏦 Bank:     {', '.join(entities['bank']) if entities['bank'] else 'None'}")
    
    # Summary
    print(f"\n{'='*70}")
    print("📊 Test Summary")
    print(f"{'='*70}")
    
    entity_ratio = total_entity_predictions / total_predictions if total_predictions > 0 else 0
    
    print(f"\n   Total predictions: {total_predictions}")
    print(f"   Entity predictions: {total_entity_predictions} ({entity_ratio:.2%})")
    
    if entity_ratio < 0.02:
        print(f"\n   ❌ WARNING: Model is predicting very few entities!")
        print(f"   This suggests the 'all O tags' problem.")
        print(f"   Recommended actions:")
        print(f"   1. Increase class_weight_multiplier to 5.0 or 10.0")
        print(f"   2. Enable focal_loss in CONFIG")
        print(f"   3. Retrain the model")
    elif entity_ratio < 0.05:
        print(f"\n   ⚠️  Model is predicting few entities (low)")
        print(f"   Consider increasing class_weight_multiplier to 4.0")
    elif entity_ratio > 0.40:
        print(f"\n   ⚠️  Model is predicting many entities (high)")
        print(f"   This might lead to false positives")
        print(f"   Consider decreasing class_weight_multiplier")
    else:
        print(f"\n   ✅ Model is predicting entities at a reasonable rate!")
        print(f"   Entity prediction rate looks healthy.")
    
    print(f"\n{'='*70}\n")

if __name__ == '__main__':
    main()
