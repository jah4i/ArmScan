# ML Kit text recognition: ArmScan bundles only the Latin model. The plugin
# references the optional Chinese/Devanagari/Japanese/Korean models, which
# are not included, so tell R8 not to fail on them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
