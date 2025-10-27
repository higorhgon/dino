using Dino.Entities;
using Dino.Ui;

extern const string GETTEXT_PACKAGE;
extern const string LOCALE_INSTALL_DIR;

namespace Dino {

void configure_macos_fonts() {
    // Check if running on macOS
    string? os_type = Environment.get_variable("OS_TYPE");
    bool is_macos = (os_type != null && os_type == "macos") || 
                    GLib.FileUtils.test("/System/Library/CoreServices/SystemVersion.plist", GLib.FileTest.EXISTS);
    
    if (!is_macos) return;
    
    // Create fontconfig directory if it doesn't exist
    string config_dir = Path.build_filename(Environment.get_home_dir(), ".config", "fontconfig");
    string config_file = Path.build_filename(config_dir, "fonts.conf");
    
    // Check if fonts.conf already exists
    if (FileUtils.test(config_file, FileTest.EXISTS)) {
        debug("fontconfig already configured at %s", config_file);
        return;
    }
    
    // Create directory
    try {
        File dir = File.new_for_path(config_dir);
        if (!dir.query_exists()) {
            dir.make_directory_with_parents();
        }
        
        // Write fontconfig to reject Apple Color Emoji and use Noto Color Emoji
        string fontconfig_content = """<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Disable Apple Color Emoji to prevent Dino crashes -->
  <selectfont>
    <rejectfont>
      <pattern>
        <patelt name="family">
          <string>Apple Color Emoji</string>
        </patelt>
      </pattern>
    </rejectfont>
  </selectfont>
  
  <!-- Use Noto Color Emoji for emoji rendering -->
  <match target="pattern">
    <test qual="any" name="family">
      <string>emoji</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Noto Color Emoji</string>
    </edit>
  </match>
  
  <!-- Fallback to Noto Color Emoji for characters not in standard fonts -->
  <match target="pattern">
    <test name="family">
      <string>sans-serif</string>
    </test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Color Emoji</string>
    </edit>
  </match>
  
  <match target="pattern">
    <test name="family">
      <string>serif</string>
    </test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Color Emoji</string>
    </edit>
  </match>
  
  <match target="pattern">
    <test name="family">
      <string>monospace</string>
    </test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Color Emoji</string>
    </edit>
  </match>
</fontconfig>
""";
        
        FileUtils.set_contents(config_file, fontconfig_content);
        debug("Created fontconfig at %s to disable Apple Color Emoji", config_file);
        
        // Set environment variable to force fontconfig reload
        Environment.set_variable("FONTCONFIG_FILE", config_file, true);
        
    } catch (Error e) {
        warning("Failed to create fontconfig: %s", e.message);
    }
}

void main(string[] args) {

    try{
        string? exec_path = args.length > 0 ? args[0] : null;
        SearchPathGenerator search_path_generator = new SearchPathGenerator(exec_path);
        Intl.textdomain(GETTEXT_PACKAGE);
        internationalize(GETTEXT_PACKAGE, search_path_generator.get_locale_path(GETTEXT_PACKAGE, LOCALE_INSTALL_DIR));

        // Configure fonts on macOS before GTK initializes
        configure_macos_fonts();

        Gtk.init();
        Dino.Ui.Application app = new Dino.Ui.Application() { search_path_generator=search_path_generator };
        Plugins.Loader loader = new Plugins.Loader(app);
        loader.load_all();

        app.run(args);
        loader.shutdown();
    } catch (Error e) {
        warning(@"Fatal error: $(e.message)");
    }
}

}
