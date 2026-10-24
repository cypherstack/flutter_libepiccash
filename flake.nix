{
  description = "Reproducible reference builds of flutter_libepiccash's Rust library";

  inputs.dnix.url = "github:slopbot9k/dnix";

  outputs = { self, dnix, ... }: dnix.lib.package {
    src = self;
    config = ./dnix.json;
  };
}
