# Final Merchant Fix - Equal B/I Weighting Strategy

## 🎯 Why Previous Attempt Failed

### Problem with Differential Weights:
```python
B-MERCHANT: 1.5×  ← Lower priority
I-MERCHANT: 2.5×  ← Higher priority
```

**What happened:**
- Model learned: "I-MERCHANT is MORE important than B-MERCHANT"
- Result: Model hesitant to predict B-MERCHANT
- Waits for I-MERCHANT signals instead
- **B-MERCHANT recall dropped: 0.63 → 0.47** ❌

### Why This Breaks IOB Logic:
- IOB tagging requires: `B-` must come BEFORE `I-`
- Differential weights confuse this sequence
- Model can't start a merchant entity properly

---

## ✅ New Strategy: Equal Weights

### Balanced Approach:
```python
B-MERCHANT: 1.8×  ← Equal priority
I-MERCHANT: 1.8×  ← Equal priority
```

**Why this works:**
- ✓ Model treats B- and I- as **coherent sequence**
- ✓ No confusion about which is "more important"
- ✓ Natural IOB flow: B-MERCHANT → I-MERCHANT → I-MERCHANT
- ✓ 1.8× is middle ground between uniform 0.8× and previous 1.5×/2.5×

### Complete Weight Scheme:
```python
<PAD>:       0.0×  (ignored)
O:           1.0×  (baseline)
B-AMOUNT:    0.8×  (already F1=0.97, reduce slightly)
I-AMOUNT:    0.8×  (match B-AMOUNT)
B-BANK:      0.8×  (already F1=0.97, reduce slightly)
I-BANK:      0.8×  (match B-BANK)
B-MERCHANT:  1.8× ⭐ (boost from 0.8, less than 2.5)
I-MERCHANT:  1.8× ⭐ (equal to B-MERCHANT!)
```

---

## 📊 Expected Results

### Target Performance:

| Metric | Uniform 0.8 | Equal 1.8 (Target) |
|--------|-------------|-------------------|
| **Overall Accuracy** | 95.03% | 95.0-95.5% |
| **B-MERCHANT Recall** | 0.63 | **0.70-0.78** (+0.07-0.15) |
| **B-MERCHANT F1** | 0.69 | **0.73-0.78** (+0.04-0.09) |
| **I-MERCHANT Recall** | 0.45 | **0.60-0.70** (+0.15-0.25) |
| **I-MERCHANT F1** | 0.61 | **0.70-0.78** (+0.09-0.17) |
| **B-AMOUNT F1** | 0.97 | 0.95-0.97 |
| **B-BANK F1** | 0.97 | 0.95-0.97 |

### Key Differences from Previous:
- ✓ Should NOT hurt B-MERCHANT (equal weight prevents confusion)
- ✓ Should improve I-MERCHANT (more than 0.8, less aggressive than 2.5)
- ✓ Maintains IOB sequence integrity

---

## 🎓 Key Insight: IOB Coherence

**For sequential tagging schemes like IOB:**
- B- and I- tags are NOT independent
- They form a **sequence** that must be coherent
- Equal weighting maintains this relationship
- Differential weighting breaks the logical flow

**Example:**
```
"MC DONALDS RESTAURANT"

Good (equal weights):
MC         → B-MERCHANT (confident)
DONALDS    → I-MERCHANT (natural continuation)
RESTAURANT → I-MERCHANT (flows naturally)

Bad (differential weights):
MC         → O (hesitant, waiting for stronger I-MERCHANT signal)
DONALDS    → I-MERCHANT? (but no B- before it - invalid!)
RESTAURANT → I-MERCHANT? (confused)
```

---

## 🚀 Running the Final Fix

```bash
python3 train_bilstm_ner.py
```

**What to watch for:**
1. B-MERCHANT recall: Should improve from 0.63
2. I-MERCHANT recall: Should improve from 0.45
3. Overall accuracy: Should maintain ~95%
4. Entity prediction rate: Should stay 10-12%

---

## 🎯 Success Criteria

### Minimum Success:
- B-MERCHANT: Recall ≥ 0.68 (+0.05 from 0.63)
- I-MERCHANT: Recall ≥ 0.55 (+0.10 from 0.45)
- Overall: ≥ 94.8%

### Good Success:
- B-MERCHANT: F1 ≥ 0.73 (+0.04 from 0.69)
- I-MERCHANT: F1 ≥ 0.70 (+0.09 from 0.61)
- Overall: ≥ 95.0%

### Excellent Success:
- B-MERCHANT: F1 ≥ 0.75 (+0.06 from 0.69)
- I-MERCHANT: F1 ≥ 0.75 (+0.14 from 0.61)
- Overall: ≥ 95.3%

---

This is the FINAL attempt. If this doesn't work significantly better than uniform 0.8×, we stick with that! 🎯
