def init
  super
  sections[:layout].place(:tasklib_list).after(:diskfile)
end
