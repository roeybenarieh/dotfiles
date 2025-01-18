{ ... }:

{
  # to control this service visit
  # http://localhost:7396 
  # or 
  # http://v8-3.foldingathome.org/machines
  services.foldingathome = {
    enable = true;
    daemonNiceLevel = 19;
    user = "Roey Ben Arieh";
  };
}
