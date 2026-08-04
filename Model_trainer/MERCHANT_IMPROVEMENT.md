# BiLSTM Merchant Detection Improvement Strategy

## 🎯 Current Problem

### Merchant Detection Issues:
- **B-MERCHANT F1: 0.69** (Precision 0.76, Recall **0.63**)
  - Missing **37% of merchants!**
  
- **I-MERCHANT F1: 0.61** (Precision 0.93, Recall **0.45**)
  - Only capturing **45%** of multi-token continuations!
  - Example: "MC DONALDS" → Might tag "MC" but miss "DONALDS"

### What's Already Working:
- ✓ B-AMOUNT: F1=0.97 (excellent)
- ✓ B-BANK: F1=0.97 (excellent)
- ✓ I-BANK: F1=1.0 (perfect)
- ✓ O: F1=0.97 (excellent)

---

## 🔧 Solution: Per-Tag Class Weights

### Old Approach (Uniform Weighting):
```python
ALL entity tags × 0.8 multiplier
```
**Problem**: Merchants avg 2.5 tokens (complex), but get same weight as amounts (1.2 tokens)

### New Approach (Per-Tag Weighting):
```python
Tag                Old Weight    New Multiplier    Strategy
──────────────────────────────────────────────────────────────
<PAD>              Ignored       0.0×             Ignore
O                  Baseline      1.0×             Keep as-is
B-AMOUNT          +0.8×          0.8×             Already perfect, reduce slightly
I-AMOUNT          +0.8×          1.0×             Keep (few samples)
B-BANK            +0.8×          0.8×             Already perfect, reduce slightly
I-BANK            +0.8×          0.8×             Already perfect, reduce slightly
B-MERCHANT        +0.8×          1.5× ⭐          BOOST! (target recall 0.63→0.80)
I-MERCHANT        +0.8×          2.5× ⭐⭐        STRONG BOOST! (0.45→0.75)
```

---

## 🎯 Target Improvements

### Expected Changes:

| Tag | Current | Target | Strategy |
|-----|---------|--------|----------|
| **B-MERCHANT** | F1=0.69 (R=0.63, P=0.76) | **F1=0.78** (R=0.80, P=0.76) | 1.5× weight boost |
| **I-MERCHANT** | F1=0.61 (R=0.45, P=0.93) | **F1=0.78** (R=0.75, P=0.93) | 2.5× weight boost |
| B-AMOUNT | F1=0.97 | F1=0.95-0.97 | 0.8× (slight reduction OK) |
| B-BANK | F1=0.97 | F1=0.95-0.97 | 0.8× (slight reduction OK) |
| **Overall** | **95.03%** | **95-96%** | Maintain or improve |

---

## 💡 Why This Works

### 1. **Merchants are Hardest Entity**
Your data shows:
- Merchant avg: **2.5 tokens** (up to 6!)
- Amount avg: 1.2 tokens
- Bank avg: 1.3 tokens

Multi-token entities need more emphasis during training.

### 2. **I-MERCHANT Critically Under-weighted**
Current results show:
- I-MERCHANT recall: **0.45** (only finding 45% of continuations!)
- This causes: "WELLNESS **FOREVER** MEDICARE" → Only tags first token

With 2.5× boost:
- Model learns: "After B-MERCHANT, likely I-MERCHANT follows"
- Captures full names: "WELLNESS **FOREVER MEDICARE LIMITED**"

### 3. **Trade-off is Acceptable**
Slight reduction in Amount/Bank weights (0.97 → 0.95 F1) is acceptable:
- They're already near-perfect
- Merchants need the help more
- Overall accuracy should stay 95%+

---

## 📊 Expected Final Results

### Optimistic Scenario (Best Case):
```
Overall Accuracy: 96.2%

B-MERCHANT:   P=0.80, R=0.82, F1=0.81  (+0.12 from 0.69)
I-MERCHANT:   P=0.93, R=0.78, F1=0.85  (+0.24 from 0.61)
B-AMOUNT:     P=0.98, R=0.93, F1=0.95  (-0.02 from 0.97)
B-BANK:       P=0.94, R=0.97, F1=0.95  (-0.02 from 0.97)
```

### Realistic Scenario (Expected):
```
Overall Accuracy: 95.5%

B-MERCHANT:   P=0.78, R=0.75, F1=0.76  (+0.07 from 0.69)
I-MERCHANT:   P=0.93, R=0.68, F1=0.79  (+0.18 from 0.61)
B-AMOUNT:     P=1.00, R=0.90, F1=0.95  (-0.02 from 0.97)
B-BANK:       P=0.94, R=0.97, F1=0.95  (-0.02 from 0.97)
```

### Conservative Scenario (Minimum Improvement):
```
Overall Accuracy: 94.8%

B-MERCHANT:   P=0.76, R=0.70, F1=0.73  (+0.04 from 0.69)
I-MERCHANT:   P=0.93, R=0.60, F1=0.73  (+0.12 from 0.61)
B-AMOUNT:     P=1.00, R=0.87, F1=0.93  (-0.04 from 0.97)
B-BANK:       P=0.94, R=0.97, F1=0.95  (-0.02 from 0.97)
```

---

## 🚀 To Run the Improved Model

```bash
cd "/Users/harshpaigude/Drive E/SMS Extractor /application_flutter_claude/Model_trainer"

# Run training with new per-tag weights
python3 train_bilstm_ner.py
```

### Training Time:
- ~20-30 minutes (same as before)
- Watch for I-MERCHANT recall improvement

---

## 🔍 What to Check After Training

### 1. Merchant Recall Improvement
```
I-MERCHANT      Precision    Recall       F1-Score
                  0.93XX      0.XX??       0.XX??
                             ↑ Should be >0.60 (was 0.45)
```

### 2. Multi-Token Merchant Examples
Look for successful detections like:
- "WELLNESS FOREVER MEDICARE LIMITED" (6 tokens)
- "MC DONALDS" (2 tokens)
- "NACH LEG DR BDECS BSNLPUNEB" (complex)

### 3. Overall Accuracy Maintained
```
✓ Overall Accuracy: 0.95XX
   Should stay ≥ 95%
```

### 4. Entity Prediction Rate
```
✓ Model is predicting entities: 11-13%
   Should stay in this range
```

---

## 🎯 Success Criteria

### Minimum Success:
- ✓ B-MERCHANT F1: **>0.72** (+0.03)
- ✓ I-MERCHANT Recall: **>0.55** (+0.10)
- ✓ Overall Accuracy: **>94.5%**

### Good Success:
- ✓ B-MERCHANT F1: **>0.75** (+0.06)
- ✓ I-MERCHANT Recall: **>0.65** (+0.20)
- ✓ Overall Accuracy: **>95%**

### Excellent Success:
- ✓ B-MERCHANT F1: **>0.78** (+0.09)
- ✓ I-MERCHANT Recall: **>0.75** (+0.30)
- ✓ Overall Accuracy: **>95.5%**

---

## 💪 Why This Should Work

### Evidence from Your Data:
1. **Merchants are longest entities** (2.5 avg tokens)
2. **Current I-MERCHANT precision is high** (0.93) - model knows what they are
3. **Low recall** (0.45) - model is too conservative in predicting them
4. **Solution**: Boost weight → Model becomes less conservative

### Proven Strategy:
- Amount/Bank already working (F1=0.97) with lower weights
- Merchants need more attention during training
- Per-tag weighting is standard for complex NER tasks

---

## 🎓 Key Insight

**Not all entities are equal!**

Your data shows:
- Amounts: Easy (single token, numeric pattern)
- Banks: Medium (1-2 tokens, limited vocabulary)
- **Merchants: Hard** (2.5 avg tokens, infinite variety)

One-size-fits-all weighting (0.8× for all) doesn't work.
**Per-tag weighting** addresses each entity's difficulty level!

---

Let's see if we can get merchant F1 from 0.69 to 0.75+! 🚀
