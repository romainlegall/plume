module Paginatable
  extend ActiveSupport::Concern

  # Pagy leve une exception sur une page hors bornes. Une URL bricolee ou un
  # lienPerime ne doit pas renvoyer une erreur 500, on ramene simplement a la
  # derniere page existant.
  def paginate(scope, per_page:)
    total = scope.count
    last_page = [ (total.to_f / per_page).ceil, 1 ].max
    requested = params[:page].to_i
    requested = 1 if requested < 1
    requested = last_page if requested > last_page

    pagy = Pagy.new(count: total, page: requested, limit: per_page)
    [ pagy, scope.offset(pagy.offset).limit(per_page) ]
  end
end
