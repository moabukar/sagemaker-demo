"""Inference script for SageMaker endpoint"""
import os
import json
import joblib
import numpy as np

def model_fn(model_dir):
    """
    Load model from the model_dir.
    Called once when endpoint starts.
    """
    model_path = os.path.join(model_dir, 'model.joblib')
    model = joblib.load(model_path)
    return model

def input_fn(request_body, content_type='text/csv'):
    """
    Parse input data.
    """
    if content_type == 'text/csv':
        # Parse CSV: "1.0,2.0,3.0,..."
        data = np.array([float(x) for x in request_body.strip().split(',')])
        return data.reshape(1, -1)
    
    elif content_type == 'application/json':
        # Parse JSON: {"features": [1.0, 2.0, 3.0, ...]}
        data = json.loads(request_body)
        if 'features' in data:
            return np.array(data['features']).reshape(1, -1)
        else:
            return np.array(data).reshape(1, -1)
    
    raise ValueError(f"Unsupported content type: {content_type}")

def predict_fn(input_data, model):
    """
    Make predictions.
    """
    prediction = model.predict(input_data)
    probability = model.predict_proba(input_data)
    
    return {
        'prediction': int(prediction[0]),
        'probabilities': probability[0].tolist(),
        'confidence': float(np.max(probability[0]))
    }

def output_fn(prediction, accept='application/json'):
    """
    Format prediction output.
    """
    if accept == 'application/json':
        return json.dumps(prediction), accept
    
    raise ValueError(f"Unsupported accept type: {accept}")
