class AttachmentsController < ApplicationController
  def show
    attachment = Attachment.includes(:message).find(params[:id])
    path = attachment.absolute_path

    unless path && File.file?(path)
      return render plain: "Piece jointe introuvable sur le disque : #{attachment.storage_path}", status: :not_found
    end

    disposition = params[:dl].present? ? "attachment" : inline_disposition(attachment)
    send_file path, type: content_type(attachment), disposition: disposition, filename: attachment.display_name
  end

  alias_method :download, :show

  private

  def inline_disposition(attachment)
    # Un PDF ou une image s'ouvre dans l'onglet, un executable se telecharge.
    attachment.image? || attachment.content_type.to_s.include?("pdf") ? "inline" : "attachment"
  end

  # Le type annonce par le mail est souvent faux ou absent : un fichier binaire
  # ne doit jamais etre servi sous un type executable.
  def content_type(attachment)
    declared = attachment.content_type.to_s.split(";").first.to_s.strip
    return declared if declared.match?(%r{\A(text/|image/|application/pdf|audio/|video/)}) &&
                        !declared.match?(%r{\Atext/html}i)

    Marcel::MimeType.for(Pathname.new(attachment.absolute_path.to_s), name: attachment.filename).to_s.presence || "application/octet-stream"
  rescue StandardError
    "application/octet-stream"
  end
end
