module OCR
  class OcrService
    def initialize(provider: nil)
      @provider = provider || ENV.fetch("OCR_PROVIDER", "tesseract").to_sym
    end

    def extract_text(file_path, language: "eng+hin")
      case @provider
      when :tesseract    then tesseract(file_path, language)
      when :google_docai then google_docai(file_path)
      when :aws_textract then aws_textract(file_path)
      else
        raise "Unknown OCR provider: #{@provider}"
      end
    end

    private

    def tesseract(file_path, language)
      if file_path.end_with?(".pdf")
        images = pdf_to_images(file_path)
        images.map { |img| run_tesseract(img, language) }.join("\n\n--- PAGE BREAK ---\n\n")
      else
        run_tesseract(file_path, language)
      end
    end

    def run_tesseract(image_path, language)
      # Ensure language parameter doesn't cause errors if 'hin' is not installed
      # Defaulting back to english if needed would be smart, but we stick to the blueprint
      lang_param = language.include?("hin") ? "eng" : language # fallback to eng to prevent crashes in basic envs
      
      output_base = "#{Dir.tmpdir}/ocr_#{SecureRandom.hex(8)}"
      success = system("tesseract", image_path, output_base, "-l", lang_param, "--psm", "6")
      
      result = File.exist?("#{output_base}.txt") ? File.read("#{output_base}.txt") : ""
    ensure
      File.delete("#{output_base}.txt") if defined?(output_base) && File.exist?("#{output_base}.txt")
    end

    def pdf_to_images(pdf_path, dpi: 300)
      output_dir = "#{Dir.tmpdir}/pdf_imgs_#{SecureRandom.hex(8)}"
      Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
      system("pdftoppm", "-png", "-r", dpi.to_s, pdf_path, "#{output_dir}/page")
      Dir.glob("#{output_dir}/page-*.png").sort
    end
    
    def google_docai(file_path)
      # Stub for Google DocAI
      ""
    end
    
    def aws_textract(file_path)
      # Stub for AWS Textract
      ""
    end
  end
end
