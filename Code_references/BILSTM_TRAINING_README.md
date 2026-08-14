# BiLSTM NER Training Guide

## 🎯 Solving the "All O Tags" Problem

This training script is specifically designed to address the most common issue in NER models: **predicting only 'O' tags and missing all entities.**

## 🔧 Quick Start

### 1. Install Dependencies

```bash
pip install pandas numpy scikit-learn tensorflow matplotlib
```

### 2. Run Training

```bash
python train_bilstm_ner.py
```

### 3. Expected Output

The script will generate:
- `sms_ner_bilstm_model.h5` - Full Keras model
- `sms_ner_bilstm_model.tflite` - TensorFlow Lite model (for Flutter)
- `word_tokenizer_bilstm.json` - Vocabulary mapping
- `tag_tokenizer_bilstm.json` - Tag index mapping
- `training_config.json` - Training configuration

---

## ⚙️ Configuration Options

### Key Parameters to Tune

Edit the `CONFIG` dictionary in `train_bilstm_ner.py`:

```python
CONFIG = {
    # Data
    'max_len': 75,                      # Max sequence length
    'test_size': 0.2,                   # Test split ratio
    'val_size': 0.1,                    # Validation split ratio
    
    # Model Architecture
    'embedding_dim': 128,               # Embedding dimension
    'lstm_units_1': 128,                # First LSTM layer units
    'lstm_units_2': 64,                 # Second LSTM layer units
    
    # Regularization (CRITICAL for preventing overfitting)
    'dropout_rate': 0.4,                # Standard dropout
    'spatial_dropout': 0.3,             # Embedding dropout
    'recurrent_dropout': 0.3,           # LSTM internal dropout
    
    # Training
    'batch_size': 16,                   # Batch size (small = better for small datasets)
    'epochs': 100,                      # Max epochs
    'learning_rate': 0.001,             # Initial learning rate
    'patience': 15,                     # Early stopping patience
    
    # Class Balancing (CRITICAL for "all O" problem)
    'class_weight_multiplier': 3.0,     # Boost entity tags (try 2.0-5.0)
    'use_focal_loss': True,             # Use focal loss instead of weighted CE
    'focal_gamma': 2.0,                 # Focal loss gamma parameter
}
```

---

## 🚨 Troubleshooting the "All O Tags" Problem

### Symptom: Model predicts >98% 'O' tags

The script will warn you:
```
⚠️  WARNING: Model is predicting very few entities (0.42%)
   This suggests the 'all O tags' problem!
```

### Solutions (in order of effectiveness):

#### 1. **Increase Class Weight Multiplier** ⭐ Most Effective

```python
'class_weight_multiplier': 5.0,  # Try 3.0, 4.0, 5.0, or even 10.0
```

This directly boosts the importance of entity tags during training.

#### 2. **Use Focal Loss** ⭐ Highly Effective

```python
'use_focal_loss': True,
'focal_gamma': 2.0,  # Higher = focus more on hard examples (try 1.5-3.0)
```

Focal loss automatically focuses on hard-to-predict examples (entities).

#### 3. **Increase Regularization**

```python
'dropout_rate': 0.5,           # Increase from 0.4
'spatial_dropout': 0.4,        # Increase from 0.3
'recurrent_dropout': 0.4,      # Increase from 0.3
```

Prevents model from "memorizing" the majority class.

#### 4. **Reduce Learning Rate**

```python
'learning_rate': 0.0005,  # Reduce from 0.001
```

Slower learning can help find better solutions.

#### 5. **Increase Model Capacity**

```python
'lstm_units_1': 256,  # Increase from 128
'lstm_units_2': 128,  # Increase from 64
```

More parameters = better entity representation.

#### 6. **Data Augmentation** (Manual)

Add more training examples by:
- Collecting more SMS data
- Creating synthetic variations
- Balancing entity distribution

---

## 📊 Monitoring Training

### Good Signs ✅

```
✓ Model is predicting entities: 15.32% of predictions
```
- Entity prediction rate: **10-20%** (matches real SMS distribution)
- Per-tag F1 scores: **>0.70** for entity tags
- Validation loss decreasing steadily

### Bad Signs ❌

```
⚠️  WARNING: Model is predicting very few entities (0.42%)
```
- Entity prediction rate: **<2%** (model collapsed to 'O')
- All entity F1 scores: **0.00**
- Validation loss plateaus early

---

## 🎯 Expected Performance

### Target Metrics

| Tag | Expected F1 | Excellent F1 |
|-----|-------------|--------------|
| **B-MERCHANT** | 0.70-0.80 | >0.85 |
| **I-MERCHANT** | 0.65-0.75 | >0.80 |
| **B-AMOUNT** | 0.85-0.92 | >0.95 |
| **I-AMOUNT** | 0.80-0.90 | >0.92 |
| **B-BANK** | 0.75-0.85 | >0.90 |
| **I-BANK** | 0.70-0.80 | >0.85 |
| **O** | 0.95+ | 0.98+ |

### Why Different Targets?

- **AMOUNT**: Easiest (numeric, consistent patterns) → expect high F1
- **BANK**: Medium (limited vocabulary) → expect good F1
- **MERCHANT**: Hardest (high vocabulary, varied formats) → accept lower F1

---

## 🔬 Advanced Tuning

### Experiment 1: High Class Weight

```python
'class_weight_multiplier': 10.0,
'use_focal_loss': False,
```

**When to use**: Model predicts <5% entities  
**Risk**: May predict too many false entities

### Experiment 2: Strong Focal Loss

```python
'class_weight_multiplier': 2.0,
'use_focal_loss': True,
'focal_gamma': 3.0,
```

**When to use**: Model has high loss but predicts only 'O'  
**Risk**: Training may be slower

### Experiment 3: Minimal Regularization

```python
'dropout_rate': 0.2,
'spatial_dropout': 0.2,
'recurrent_dropout': 0.2,
```

**When to use**: Model underfits (low training accuracy)  
**Risk**: Overfitting on small dataset

### Experiment 4: Maximum Regularization

```python
'dropout_rate': 0.6,
'spatial_dropout': 0.5,
'recurrent_dropout': 0.5,
```

**When to use**: Model overfits (training acc >> validation acc)  
**Risk**: Underfitting

---

## 📈 Understanding Class Weights

### What the Script Shows:

```
📊 Tag Distribution (Before Weighting):
   <PAD>          :  12450 (82.93%)
   O              :   1850 (12.32%)
   B-MERCHANT     :    120 ( 0.80%)
   I-MERCHANT     :    180 ( 1.20%)
   B-AMOUNT       :    120 ( 0.80%)
   I-AMOUNT       :     90 ( 0.60%)
   B-BANK         :    120 ( 0.80%)
   I-BANK         :     70 ( 0.47%)

⚖️  Final Class Weights:
   <PAD>          : 0.0012    ← Very low (ignored)
   O              : 0.6543    ← Baseline
   B-MERCHANT     : 50.3580   ← 3x multiplier!
   I-MERCHANT     : 33.5720   ← 3x multiplier!
   B-AMOUNT       : 50.3580   ← 3x multiplier!
   I-AMOUNT       : 67.1440   ← 3x multiplier!
   B-BANK         : 50.3580   ← 3x multiplier!
   I-BANK         : 86.2870   ← 3x multiplier!
```

### Interpretation:

- **PAD**: Nearly ignored (weight ≈ 0)
- **O**: Baseline weight (1x)
- **Entity tags**: Boosted 30-80x! This forces the model to learn entities.

---

## 🧪 Testing Your Model

### Quick Test Script

Create `test_model.py`:

```python
import numpy as np
import json
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.sequence import pad_sequences

# Load model and tokenizers
model = load_model('sms_ner_bilstm_model.h5', compile=False)

with open('word_tokenizer_bilstm.json') as f:
    word_data = json.load(f)
    word2idx = {v: int(k) for k, v in word_data['config']['index_word'].items()}
    word2idx = {k: v for v, k in word2idx.items()}  # Reverse

with open('tag_tokenizer_bilstm.json') as f:
    idx2tag = json.load(f)['idx2tag']
    idx2tag = {int(k): v for k, v in idx2tag.items()}

# Test SMS
test_sms = "Sent Rs.125.00 From HDFC Bank To MC DONALDS"

# Tokenize
tokens = test_sms.lower().split()
sequence = [word2idx.get(token, 1) for token in tokens]
padded = pad_sequences([sequence], maxlen=75, padding='post')

# Predict
predictions = model.predict(padded, verbose=0)
predicted_tags = np.argmax(predictions[0], axis=-1)

# Display
print(f"\nTest SMS: {test_sms}\n")
print(f"{'Token':<20} {'Predicted Tag'}")
print("-" * 40)
for token, tag_idx in zip(tokens, predicted_tags):
    tag = idx2tag[tag_idx]
    print(f"{token:<20} {tag}")
```

---

## 📦 Using the Model in Flutter

Replace these files in your Flutter project:

```bash
# Copy TFLite model
cp sms_ner_bilstm_model.tflite assets/

# Copy tokenizers
cp word_tokenizer_bilstm.json assets/
cp tag_tokenizer_bilstm.json assets/
```

Update `ml_service.dart`:

```dart
Future<void> loadModel({
  String modelAsset = 'assets/sms_ner_bilstm_model.tflite',
  String wordTokAsset = 'assets/word_tokenizer_bilstm.json',
  String tagTokAsset = 'assets/tag_tokenizer_bilstm.json',
}) async {
  // Your existing loading code
}
```

---

## 🎓 Tips for Success

### Do's ✅

1. **Start with provided config** - it's already optimized
2. **Monitor entity prediction rate** - should be 10-20%
3. **Use class weights** - essential for imbalanced data
4. **Try focal loss** - often works better than weighted CE
5. **Be patient** - training may take 30-60 minutes
6. **Save best model** - early stopping prevents overfitting

### Don'ts ❌

1. **Don't remove regularization** - small dataset = high overfitting risk
2. **Don't use huge batches** - small batches generalize better
3. **Don't skip validation** - you need to detect overfitting
4. **Don't ignore warnings** - the script will tell you if there's a problem
5. **Don't expect perfection** - 80% F1 on entities is good for 211 samples

---

## 📞 Common Issues

### Issue: "Model only predicts 'O' tags"
**Solution**: Increase `class_weight_multiplier` to 5.0 or enable focal loss

### Issue: "Training loss is NaN"
**Solution**: Reduce learning rate to 0.0001

### Issue: "Validation accuracy decreases after epoch 5"
**Solution**: Overfitting - increase dropout or reduce model size

### Issue: "F1 score for entities is 0.00"
**Solution**: Class imbalance - increase `class_weight_multiplier` to 10.0

### Issue: "Training is very slow"
**Solution**: Reduce `lstm_units_1` to 64, or use GPU

---

## 🚀 Next Steps

1. **Run the script**: `python train_bilstm_ner.py`
2. **Check the warning**: Look for entity prediction rate
3. **Tune if needed**: Adjust class weights or focal loss
4. **Test the model**: Use `test_model.py`
5. **Deploy to Flutter**: Copy TFLite and tokenizers

---

Good luck with your training! 🎯
