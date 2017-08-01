class SearchesController < ApplicationController
  PER_PAGE = 10
  layout 'main'

  before_action :read_page

  def show
    @query = params[:q]
    @type = params[:type] || 'casebooks'

    @results = if @query
      type_groups @query
    else
      type_groups '*'
    end

    if @results[@type.to_sym].nil? && !params[:partial]
      @type = @results.select { |key, value| value.present? }.keys.first.to_s || 'casebooks'
    end

    @paginated_group = paginate_group @results[@type.to_sym]
    @filters = build_filters @results[:casebooks]

    if params[:partial]
      render partial: 'results', layout: false, locals: {paginated_group: @paginated_group}
    end
  end

  def index
    @type = params[:type] || 'casebooks'
    @results = type_groups '*'
    @casebook_results = @results[:casebooks]

    @filters = build_filters @casebook_results
    @paginated_group = paginate_group @casebook_results

    render 'searches/show'
  end

  private

  def build_filters results
    results_group = results.try(:results)
    authors = []
    schools = []

    results_group.map do |result|
      authors.push result.owner unless authors.include?(result.owner)
      schools.push result.owner.affiliation unless schools.include?(result.owner.affiliation)
    end 

    { authors: authors, schools: schools }
  end

  def paginate_group group
    WillPaginate::Collection.create(@page, PER_PAGE, group.try(:total) || 0) do |pager|
       pager.replace(group.try(:results) || [])
    end
  end

  def read_page
    @page = (params[:page] || 1).to_i
  end

  def schools
    a = User.all.map { |user| user.affiliation }.uniq
  end

  def type_groups query
    groups = search_query(@query).group(:klass).groups
    return {
      casebooks: groups.find {|r| r.value == 'Content::Casebook'},
      cases: groups.find {|r| r.value == 'Case'},
      users: groups.find {|r| r.value == 'User'}
    }
  end

  def search_query query
    page = @page
    Sunspot.search Case, Content::Casebook, User do
      keywords query

      any_of do
        with :public, true
        if current_user.present?
          with :owner_ids, current_user.id
        end
      end

      with :owner_ids, params[:author] if params[:author].present?
      with :owner_affiliation, params[:school] if params[:school].present?

      order_by (params[:sort] || 'display_name').to_sym
      group :klass do
        limit PER_PAGE
      end

      adjust_solr_params do |params|
        params['group.offset'] = (page - 1) * PER_PAGE
      end
    end
  end
end
