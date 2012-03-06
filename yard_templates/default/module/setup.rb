def init
  super
  sections.place(:task_definition).after(T('docstring'))
  sections.place(:settings, [:setting_summary]).before(:attribute_summary)
end

def prune_method_listing(list, hide_attrs=true)
  list = super
  list.reject do |o|
    unless CodeObjects::Proxy === o.namespace or o.namespace[:settings].nil?
      o.namespace[:settings].include?(o)
    else
      false
    end
  end
end
