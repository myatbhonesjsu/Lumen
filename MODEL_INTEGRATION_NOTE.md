# Model Integration Note – Sriyavarma Saripella

This branch (`ai-skin-notebook`) contains the full machine learning development for the
AI Skin Detection model used in the Lumen project.

The model was trained and tested in Google Colab using EfficientNet-B0 for detecting
skin conditions (acne, wrinkles, dark spots, pores, etc.).

Due to framework differences (Python model vs. Swift-based iOS app), the model was not
merged into the `main` branch but is referenced as the AI backend source for the app.

These notebooks demonstrate the working AI logic, dataset visualization, and inference
outputs that support the final project.
