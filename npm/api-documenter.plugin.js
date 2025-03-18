class UniqueFilenameFeature {
  constructor(initialization) {
    this._initialization = initialization;
  }

  onBeforeWritePage(eventArgs) {
    const kind = eventArgs.apiItem.kind.toLowerCase();
    const extIndex = eventArgs.outputFilename.lastIndexOf(".md");
    eventArgs.outputFilename =
      eventArgs.outputFilename.slice(0, extIndex) + "-" + kind + ".md";
  }

  onInitialized() {
    // optional: run code when feature is initialized
  }
}

module.exports.apiDocumenterPluginManifest = {
  manifestVersion: 1000,            // ✅ required
  pluginName: "unique-filename-plugin",
  pluginVersion: "1.0.0",
  features: [
    {
      featureName: "uniqueFilenameMarkdown",
      kind: "MarkdownDocumenterFeature",
      subclass: UniqueFilenameFeature
    }
  ]
};
