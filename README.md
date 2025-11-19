#  AI Skin Condition Detection – Model Notebook

This notebook implements and trains the **AI model** that powers Lumen’s skin condition analysis feature.  
It uses **EfficientNet-B0** for multi-class skin condition classification and provides real-time skincare recommendations.

---

##  Overview
The notebook prepares and trains an AI model that detects and classifies common **cosmetic skin conditions** such as:
- Acne  
- Wrinkles  
- Dry Skin  
- Oily Skin  
- Pores  
- Blackheads  
- Whiteheads  
- Dark Spots  
- Skin Redness  
- Eyebags  

The model also gives **personalized skincare advice** based on the detected condition.

---

##  Technologies Used
- **PyTorch** — for deep learning model training  
- **EfficientNet-B0** — pretrained CNN architecture for feature extraction  
- **Google Colab GPU Runtime** — for training and inference  
- **Matplotlib & Seaborn** — for result visualization and confusion matrices  
- **Kaggle API & Roboflow Datasets** — for dataset download and preprocessing  
- **Grad-CAM Visualization (added)** — to interpret model focus areas  

---

##  Key Features
 **Dataset Integration:** Combined datasets from **Kaggle (Skin Issues v2)** and **Roboflow** for balanced training data.  
 **Custom Data Pipeline:** Preprocessed 9,000+ images into train/validation splits.  
 **Model Training:** Fine-tuned EfficientNet-B0 achieving ~98 % validation accuracy.  
 **Evaluation Metrics:** Generated classification report and confusion matrix.  
 **Grad-CAM Visualization:** Added explainability by showing where the model focuses when predicting.  
 **Skincare Recommendation Engine:** Linked predictions to customized cosmetic care suggestions.

---

##  How to Use
1. Open the notebook: [`272_Skin_Agentic.ipynb`](272_Skin_Agentic.ipynb)  
2. Run all cells (GPU recommended).  
3. Upload a face or skin image.  
4. The notebook will display:  
   - Detected condition  
   - Confidence score  
   - Skincare advice  
   - Grad-CAM heatmap visualization  

---

##  Results
- **Model Accuracy:** ≈ 98 % (Weighted Avg)  
- **Strong Predictions:** Acne, Wrinkles, Dark Spots  
- **Visualization:** Grad-CAM heatmaps highlight model attention on actual skin issues.

---

##  Author Contribution
**Developed by:** _Sriyavarma Saripella_  
- Built and trained the deep learning model for skin condition detection  
- Integrated Grad-CAM for explainability  
- Evaluated model accuracy and visual results  
- Linked AI output with personalized cosmetic recommendations  

---

This notebook enhances the **transparency and accuracy** of Lumen’s AI-powered skincare assistant by combining interpretable AI techniques with high-performance model training.

---


