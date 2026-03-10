{ config, ... }:
{
  download_directory = "${config.home.homeDirectory}/Downloads";
  record_download_history = true;
  has_migrated_from_v8 = true;
  used_history_button = true;
  last_advanced_download = 1;
  successfull_dl = 1;
  download_history = {
    __serializer_tag = "map";
    __serializer_value = [
      {
        __serializer_tag = "array";
        __serializer_value = [
          {
            __serializer_tag = "primitive";
            __serializer_value = "downloadable_2857569457442918";
          }
          {
            download_result = {
              inbrowser = {
                __serializer_tag = "primitive";
                __serializer_value = false;
              };
              filepath = {
                __serializer_tag = "primitive";
                __serializer_value = "/home/roey/Downloads/End of Beginning - YouTube.mp4";
              };
              filename = {
                __serializer_tag = "primitive";
                __serializer_value = "End of Beginning - YouTube.mp4";
              };
              filedir = {
                __serializer_tag = "primitive";
                __serializer_value = "/home/roey/Downloads";
              };
              qrcode = {
                __serializer_tag = "primitive";
                __serializer_value = false;
              };
            };
            page_url = {
              __serializer_tag = "primitive";
              __serializer_value = "https://www.youtube.com/watch?v=Kf5pXDhx5Vc";
            };
            timestamp = {
              __serializer_tag = "primitive";
              __serializer_value = 1740826193634;
            };
          }
        ];
      }
    ];
  };
  view_options = {
    all_tabs = false;
    low_quality = false;
    sort_by_status = true;
    sort_reverse = false;
    show_button_clean = true;
    show_button_clean_all = false;
    show_button_convert_local = false;
    hide_downloaded = false;
  };
  theme = "system";
}
