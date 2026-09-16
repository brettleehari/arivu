// spine: C1 — the model ships inside the install as an install-time asset pack; no download step.
plugins {
    alias(libs.plugins.android.asset.pack)
}

assetPack {
    packName.set("modelpack")
    dynamicDelivery {
        deliveryType.set("install-time")
    }
}

// Source of truth is models/ (tools/fetch_model.sh verifies the sha256). The asset name is
// Policy.MODEL_ASSET in :app.
val stageModel = tasks.register<Copy>("stageModel") {
    val src = rootProject.file("../models/Qwen3-0.6B-Q4_K_M.gguf")
    doFirst { check(src.exists()) { "Model missing: run tools/fetch_model.sh" } }
    from(src) { rename { "qwen3-0.6b-q4_k_m.gguf.so" } }  // ".so": page alignment, D-013
    into(layout.projectDirectory.dir("src/main/assets/model"))
}
tasks.configureEach { if (name != "stageModel" && name != "clean") dependsOn(stageModel) }
