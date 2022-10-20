[
  inputs: [
    "{lib,test,config}/**/*.{ex,exs}",
    "c_src/**/*.spec.exs",
    ".formatter.exs",
    "*.exs"
  ],
  import_deps: [:membrane_core, :bundlex, :unifex]
]
