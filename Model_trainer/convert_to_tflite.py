"""
Optimized TFLite Conversion for BiLSTM Model (TensorFlow 2.10+)
Eliminates SelectOps for pure TFLite compatibility with Flutter
"""

import tensorflow as tf
from tensorflow import keras
import numpy as np

print(f"TensorFlow version: {tf.__version__}")

# Load the best BiLSTM model
model_path = 'best_model.h5'
print(f"\n📦 Loading model from {model_path}...")
model = keras.models.load_model(model_path, compile=False)
print(f"✓ Model loaded successfully")

# Print model summary
print(f"\n📐 Model Architecture:")
model.summary()

# ==========================================
# OPTIMIZED TFLITE CONVERSION
# ==========================================

print(f"\n{'='*70}")
print("🔧 CONVERTING TO TFLITE (Optimized for TF 2.10+)")
print(f"{'='*70}\n")

# Method 1: Default conversion (try first)
print("Method 1: Default conversion...")
try:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # TF 2.10 specific settings
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,  # Use built-in ops only
    ]
    
    # Experimental flags for better LSTM support (TF 2.10+)
    converter._experimental_lower_tensor_list_ops = True
    converter.experimental_new_converter = True
    
    tflite_model = converter.convert()
    
    output_path = 'sms_ner_bilstm_optimized.tflite'
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✅ SUCCESS! Saved: {output_path}")
    print(f"   Size: {len(tflite_model) / 1024:.2f} KB")
    print(f"   Pure TFLite (no SelectOps)")
    
except Exception as e:
    print(f"❌ Method 1 failed: {str(e)[:100]}...")
    
    # Method 2: With SelectOps (fallback)
    print(f"\nMethod 2: With TensorFlow SelectOps...")
    try:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Allow SelectOps (larger but more compatible)
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS  # Include TF ops
        ]
        converter._experimental_lower_tensor_list_ops = False
        
        tflite_model = converter.convert()
        
        output_path = 'sms_ner_bilstm_selectops.tflite'
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"✅ SUCCESS with SelectOps! Saved: {output_path}")
        print(f"   Size: {len(tflite_model) / 1024:.2f} KB")
        print(f"   ⚠️  Requires SELECT_TF_OPS delegate in Flutter")
        
    except Exception as e:
        print(f"❌ Method 2 also failed: {str(e)[:100]}...")
        
        # Method 3: Dynamic range quantization
        print(f"\nMethod 3: Dynamic range quantization...")
        try:
            converter = tf.lite.TFLiteConverter.from_keras_model(model)
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            converter.target_spec.supported_ops = [
                tf.lite.OpsSet.TFLITE_BUILTINS,
                tf.lite.OpsSet.SELECT_TF_OPS
            ]
            
            # Try dynamic range quantization
            converter._experimental_lower_tensor_list_ops = False
            converter.experimental_new_converter = True
            
            tflite_model = converter.convert()
            
            output_path = 'sms_ner_bilstm_quantized.tflite'
            with open(output_path, 'wb') as f:
                f.write(tflite_model)
            
            print(f"✅ SUCCESS with quantization! Saved: {output_path}")
            print(f"   Size: {len(tflite_model) / 1024:.2f} KB")
            
        except Exception as e:
            print(f"❌ Method 3 also failed: {str(e)[:100]}")
            print(f"\n💡 BiLSTM LSTM layers are not fully TFLite compatible.")
            print(f"   Consider using simpler model or server-side inference.")

print(f"\n{'='*70}")
print("✅ CONVERSION COMPLETE")
print(f"{'='*70}\n")

# Test the converted model (if successful)
import os
if os.path.exists('sms_ner_bilstm_optimized.tflite'):
    print("🧪 Testing optimized TFLite model...")
    
    # Load TFLite model
    interpreter = tf.lite.Interpreter(model_path='sms_ner_bilstm_optimized.tflite')
    interpreter.allocate_tensors()
    
    # Get input/output details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"   Input shape: {input_details[0]['shape']}")
    print(f"   Output shape: {output_details[0]['shape']}")
    
    # Test with dummy input
    test_input = np.array([[1, 2, 3, 4, 5] + [0]*70], dtype=np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_input)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    
    print(f"   ✓ Model inference successful!")
    print(f"   Output shape: {output.shape}")
    
elif os.path.exists('sms_ner_bilstm_selectops.tflite'):
    print("📌 To use SelectOps model in Flutter:")
    print("   1. Add to pubspec.yaml:")
    print("      ```yaml")
    print("      tflite_flutter:")
    print("        enable-select-tf-ops: true")
    print("      ```")
    print("   2. Model will be larger but work correctly")

print("\n" + "="*70)
print("📊 SUMMARY")
print("="*70)
print("\n Check which .tflite files were created above.")
print(" Use the smallest/fastest one that worked!")
