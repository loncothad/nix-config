{ inputs, ... }:

{
  programs.mark-shot = {
    enable = true;
    package = inputs.mark-shot.packages.mark-shot;

    settings = {
      ui = {
        language = "system";
        theme = "system";
      };

      annotation = {
        defaultTool = "move";
        fullscreenDefaultTool = "laser";
        defaultColor = "#FF4D4D";
      };

      save = {
        pathTemplate = "{pictures}/mark-shot/{datetime}.png";
      };

      export = {
        imageFrame = {
          enabled = true;
          padding = 64;
          cornerRadius = 12;
          shadowRadius = 48;
          shadowOffsetY = 16;
          shadowOpacity = 0.25;
        };
      };

      windowDetection = {
        enabled = true;
        command = "mark-shot-window-detection-niri";
      };

      scrollCapture = {
        frame = 5;
        previewGap = 5;
        hidePreviewDuringCapture = false;
      };

      ocr = {
        enabled = true;
        backend = "rapidocr";
      };
    };

    extensions = {
      commands = [
        {
          name = "OCR Selection";
          command = "mark-shot-ocr --format json --backend rapidocr {image}";
          saveImage = true;
        }
      ];
    };
  };
}
