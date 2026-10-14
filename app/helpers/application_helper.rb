module ApplicationHelper
  def initials(name)
    parts = name.to_s.scan(/[[:alpha:]][[:alpha:]'’-]*/).first(2)
    return "?" if parts.empty?

    parts.map { |word| word[0] }.join.upcase
  end

  # Assainit le HTML du message en substituant ses images embarquees par les
  # pieces jointes locales stockees avec lui. Le resultat est memorise : la vue
  # s'y appelle plusieurs fois (corps, compteur d'images distantes).
  def sanitized_email_html(message)
    email_html(message)&.html_safe
  end

  def remote_image_count(message)
    html = email_html(message)
    return 0 if html.blank?

    Nokogiri::HTML5.fragment(html.to_s).css("img[data-src-bloquee]").size
  end

  private

  def email_html(message)
    @email_html ||= {}
    return @email_html[message.id] if @email_html.key?(message.id)

    @email_html[message.id] = EmailSanitizer.sanitize(
      message.body_html,
      inline_index: inline_index(message)
    )
  end

  def inline_index(message)
    @inline_index ||= {}
    @inline_index[message.id] ||= message.attachments
                                .inline
                                .filter_map { |a| [ a.content_id.to_s.downcase, a ] if a.content_id.present? }
                                .to_h
  end
end
