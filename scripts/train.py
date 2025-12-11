"""Training script for SageMaker"""
import argparse
import os
import json
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score, classification_report

def parse_args():
    parser = argparse.ArgumentParser()
    
    # Hyperparameters
    parser.add_argument('--n-estimators', type=int, default=100)
    parser.add_argument('--max-depth', type=int, default=5)
    parser.add_argument('--min-samples-split', type=int, default=2)
    
    parser.add_argument('--model-dir', type=str, default=os.environ.get('SM_MODEL_DIR', '/opt/ml/model'))
    parser.add_argument('--train', type=str, default=os.environ.get('SM_CHANNEL_TRAIN', '/opt/ml/input/data/train'))
    parser.add_argument('--output-data-dir', type=str, default=os.environ.get('SM_OUTPUT_DATA_DIR', '/opt/ml/output'))
    
    return parser.parse_args()

def load_data(data_dir):
    """Load training data"""
    train_file = os.path.join(data_dir, 'train.csv')
    print(f"Loading data from {train_file}")
    
    df = pd.read_csv(train_file)
    X = df.drop('target', axis=1)
    y = df['target']
    
    print(f"Loaded {len(df)} samples with {X.shape[1]} features")
    return X, y

def train_model(X, y, args):
    """Train the model"""
    print(f"Training RandomForest with n_estimators={args.n_estimators}, max_depth={args.max_depth}")
    
    model = RandomForestClassifier(
        n_estimators=args.n_estimators,
        max_depth=args.max_depth,
        min_samples_split=args.min_samples_split,
        random_state=42,
        n_jobs=-1
    )
    
    model.fit(X, y)
    return model

def evaluate_model(model, X, y):
    """Evaluate model performance"""
    y_pred = model.predict(X)
    
    accuracy = accuracy_score(y, y_pred)
    f1 = f1_score(y, y_pred, average='weighted')
    
    print(f"\nTraining Metrics:")
    print(f"Accuracy: {accuracy:.4f}")
    print(f"F1 Score: {f1:.4f}")
    print("\nClassification Report:")
    print(classification_report(y, y_pred))
    
    return {
        'accuracy': float(accuracy),
        'f1_score': float(f1)
    }

def save_model(model, model_dir):
    """Save model artifact"""
    os.makedirs(model_dir, exist_ok=True)
    model_path = os.path.join(model_dir, 'model.joblib')
    
    print(f"Saving model to {model_path}")
    joblib.dump(model, model_path)

def save_metrics(metrics, output_dir):
    """Save metrics for SageMaker"""
    os.makedirs(output_dir, exist_ok=True)
    metrics_path = os.path.join(output_dir, 'metrics.json')
    
    with open(metrics_path, 'w') as f:
        json.dump(metrics, f)
    
    print(f"Saved metrics to {metrics_path}")

if __name__ == '__main__':
    args = parse_args()
    
    X_train, y_train = load_data(args.train)
    
    model = train_model(X_train, y_train, args)
    
    metrics = evaluate_model(model, X_train, y_train)
    
    save_model(model, args.model_dir)
    save_metrics(metrics, args.output_data_dir)
    
    print("\nTraining complete!")