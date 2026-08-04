# BiLSTM Quick Retune - Changes Explained

## 🎯 Goal: Fix Over-Prediction Problem

### ❌ Previous Results (with default config):
- Overall Accuracy: **55.52%** (terrible!)
- Entity Predictions: **57.37%** (way too high!)
- Problem: Model predicts entities everywhere

### ✅ Target Results (with optimized config):
- Overall Accuracy: **80-88%** (competitive with 1D CNN)
- Entity Predictions: **15-20%** (normal for SMS)
- Goal: Balanced precision and recall

---

## 🔧 Key Changes Made:

### 1. **Class Weight Multiplier: 3.0 → 0.8** ⭐ MOST IMPORTANT
**Why**: The 3.0 multiplier made the model obsessed with finding entities
- Previous: Entity tags weighted 30-80x higher than 'O'
- Result: Model predicted "B-MERCHANT" for almost everything
- New: 0.8x weight = gentle boost, not aggressive over-weighting

**Expected Impact**: Entity predictions drop from 57% to ~15-20%

### 2. **CRF: Enabled → Disabled**
**Why**: 
- CRF can't convert to TFLite (deployment blocker)
- Adds complexity your small dataset (211 samples) doesn't need
- BiLSTM alone is powerful enough

**Expected Impact**: 
- TFLite conversion might work now!
- Simpler model, less overfitting
- Model size reduction

### 3. **Focal Loss: Disabled → Enabled (gamma=2.5)**
**Why**: Better for imbalanced data than weighted crossentropy
- Automatically focuses on hard-to-predict examples
- Reduces aggressive weighting
- Gamma=2.5 (higher) = more focus on difficult cases

**Expected Impact**: Better balance between precision and recall

### 4. **Architecture: Smaller Network**
- LSTM units: 128→64, 64→32
- **Why**: 211 samples is small, large network overfits
- Smaller = better generalization

### 5. **Regularization: Lower Dropout**
- Dropout: 0.4→0.3, 0.3→0.2, 0.3→0.2
- **Why**: Your data is clean (not noisy)
- Lower dropout = model can learn better

### 6. **Training: Smaller Batches**
- Batch size: 16 → 8
- Learning rate: 0.001 → 0.0005
- **Why**: Smaller batches = better generalization for small datasets
- Lower LR = more stable training

---

## 📊 Expected Changes:

| Metric | Before | After (Expected) |
|--------|--------|------------------|
| **Overall Accuracy** | 55.52% | **80-88%** |
| **Entity Predictions** | 57.37% | **15-20%** |
| **B-AMOUNT Precision** | 0.16 | **0.85-0.95** |
| **B-MERCHANT Precision** | 0.20 | **0.70-0.85** |
| **B-BANK Precision** | 0.24 | **0.75-0.90** |
| **O Precision** | 1.00 | **0.95-0.98** |
| **TFLite Conversion** | ❌ Failed | **Maybe works!** |

---

## 🚀 Run the Retuned Model:

```bash
cd "/Users/harshpaigude/Drive E/SMS Extractor /application_flutter_claude/Model_trainer"

# Make sure dependencies are installed
pip install pandas scikit-learn tensorflow-addons

# Run training with new config
python3 train_bilstm_ner.py
```

### ⏱️ Expected Training Time:
- ~20-30 minutes (similar to before)
- Watch for early stopping (might finish sooner)

---

## 🎯 Success Criteria:

### Minimum Success:
- ✓ Overall Accuracy: **>80%** (beats current 55%)
- ✓ Entity Predictions: **15-25%** (down from 57%)
- ✓ TFLite conversion: **Works** (no CRF now)

### Good Success:
- ✓ Overall Accuracy: **82-85%** (close to 1D CNN)
- ✓ Precision/Recall balanced (both >0.75)

### Great Success:
- ✓ Overall Accuracy: **>87%** (beats 1D CNN!)
- ✓ TFLite works
- ✓ Smaller model size than before

---

## 🔍 What to Check After Training:

Look for these sections in output:

### 1. During Training:
```
📊 Tag Distribution (Before Weighting):
   <PAD>: XXXX (XX%)
   O: XXXX (XX%)      ← Should be 70-80%
   B-MERCHANT: XX (X%)  ← Should be 2-5%
   ...

⚖️  Final Class Weights:
   O: 0.XXXX          ← Should be lower than before
   B-MERCHANT: X.XXXX ← Should be more balanced
```

### 2. After Evaluation:
```
✓ Model is predicting entities: XX.XX% of predictions
   ↑ Should be 15-20%, NOT 57%!

Tag             Precision    Recall       F1-Score
B-AMOUNT        0.8XXX       0.8XXX       0.8XXX  ← Should be >0.80
B-MERCHANT      0.7XXX       0.7XXX       0.7XXX  ← Should be >0.70
```

### 3. TFLite Conversion:
```
✓ Saved TFLite model: sms_ner_bilstm_model.tflite
   ↑ Success! Or still fails?
```

---

## 💡 If Results Are Still Poor:

Try these iterations:

### If still over-predicting (>30% entities):
- Lower class_weight to 0.5 or 0.3
- Increase focal_gamma to 3.0

### If under-predicting (<10% entities):
- Increase class_weight to 1.2 or 1.5
- Check if model is learning at all

### If accuracy plateaus at 70-75%:
- More training data needed (collect more SMS)
- Or stick with your 1D CNN (it's already great!)

---

## 🎓 Key Insight:

The previous config was tuned for **giant NER datasets** (thousands of samples).
Your dataset is **small and clean** (211 samples), so it needs:
- Lower regularization
- Smaller architecture  
- Gentler class balancing
- Focal loss instead of aggressive weighting

Let's see if BiLSTM can now compete with your 1D CNN! 🚀
