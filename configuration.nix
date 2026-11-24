{ config, pkgs, ... }:

{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  fileSystems."/srv/media" = {
    device = "/dev/disk/by-uuid/64b58b6f-c8d8-4faf-b690-edeb1e692996";
    fsType = "xfs";
    options = [ "nofail" ];
    neededForBoot = true;
  };

  systemd.services.create-media-dirs = {
    description = "Create /srv/media library dirs on the media volume";
    after = [ "srv-media.mount" ];
    requires = [ "srv-media.mount" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=/srv/media";
    };
  };

  systemd.tmpfiles.rules = [
    # The leading 2 in 2775 makes subdirectories inherit the group of the parent directory.
    # Nixarr creates library/{shows,movies,music,books} and the qbittorrent category dirs.
    "d /srv/zotero              2770 root zotero -"
    "d /srv/media               2775 root media -"
    "d /srv/media/library       2775 root media -"
    "d /srv/media/library/manga 2775 root media -"
  ];

  networking = {
    hostName = "HomeServer"; # Define your hostname.
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 80 ];
    hosts = {
      "127.0.0.1" = [
        "jellyfin.home"
        "qbittorrent.home"
        "sonarr.home"
        "radarr.home"
        "prowlarr.home"
        "seerr.home"
      ];
    };
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.groups = {
    media = { };
    zotero = { };
  };

  nix.settings.trusted-users = [ "root" "@wheel" ];

  users.users = {
		"ben" = {
			isNormalUser = true;
			description = "ben";
			extraGroups = [ "networkmanager" "wheel" "media" "zotero" ];
			openssh.authorizedKeys.keys = [
				"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEqfzwmJVsL6IvKQ2+tMQWhMXgTUqGFwi9W7o1PWI0YR brbarnhart99@gmail.com"
				"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJymR9os8EZo2ol8B9kyEIIB//uQJ2prZWbLIn+qReOT brbarnhart99@gmail.com"
			];
			packages = with pkgs; [];
		};
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;  # fine even before you use TLS

    virtualHosts = {
      "jellyfin.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
        };
      };
      "qbittorrent.home" = {
        locations."/" = {
				proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
        };
      };
      "sonarr.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8989";
          proxyWebsockets = true;
        };
      };
      "radarr.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:7878";
          proxyWebsockets = true;
        };
      };
      "prowlarr.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:9696";
          proxyWebsockets = true;
        };
      };
      "seerr.home" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:5055";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    # settings = {
    #   PasswordAuthentication = false;
    #   KbdInteractiveAuthentication = false;
    #   PermitRootLogin = "no";
    # };
  };

  # Localhost API access for settings-sync. "External" still requires a login
  # through nginx; the sync units use the API keys Nixarr extracts.
  services.sonarr.settings.auth.required = "External";
  services.radarr.settings.auth.required = "External";
  services.prowlarr.settings.auth.required = "External";

  nixarr = {
    enable = true;
    mediaDir = "/srv/media";
    stateDir = "/var/lib/nixarr";
    mediaUsers = [ "ben" ];

    jellyfin = {
      enable = true;
      openFirewall = true;
    };

    qbittorrent = {
      enable = true;
      openFirewall = true;
      qui.enable = false;
      webuiPort = 8080;
      peerPort = 6881;
      extraConfig = {
        LegalNotice.Accepted = true;
        Preferences = {
          "WebUI\\Username" = "bbarnhart";
          "WebUI\\Password_PBKDF2" = "@ByteArray(zfkioBnV+p4yAfohG1b1UA==:JLsPOq5scIA1srkMoXs/Fv+kb0UMXoQKYJx1hGSCBNVsh1ZrH+dcVrFUB8weHxT8FRivOAsxz6hGrQS8bHTTrw==)";
        };
      };
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
      settings-sync = {
        enable-nixarr-apps = true;
        # Indexer credentials are not in this repo. Add one entry per indexer, for example:
        # indexers = [{
        #   name = "Indexer name";
        #   sort_name = "from `nixarr show-prowlarr-schemas indexer`";
        #   fields.apiKey.secret = "/var/lib/nixarr/indexer-api-key";
        # }];
      };
    };

    sonarr = {
      enable = true;
      openFirewall = true;
      settings-sync.downloadClients = [
        {
          name = "qBittorrent";
          implementation = "QBittorrent";
          fields = {
            host = "localhost";
            port = 8080;
            useSsl = false;
            username = "bbarnhart";
            password.secret = "/var/lib/nixarr/qbittorrent-password";
            category = "sonarr";
          };
        }
      ];
    };

    radarr = {
      enable = true;
      openFirewall = true;
      settings-sync.downloadClients = [
        {
          name = "qBittorrent";
          implementation = "QBittorrent";
          fields = {
            host = "localhost";
            port = 8080;
            useSsl = false;
            username = "bbarnhart";
            password.secret = "/var/lib/nixarr/qbittorrent-password";
            movieCategory = "radarr";
          };
        }
      ];
    };

    seerr = {
      enable = true;
      openFirewall = true;
    };

    recyclarr = {
      enable = true;
      configuration = {
        sonarr.series = {
          base_url = "http://localhost:8989";
          api_key = "!env_var SONARR_API_KEY";
          delete_old_custom_formats = false;
          quality_definition.type = "series";
          media_naming = {
            series = "default";
            season = "default";
            episodes = {
              rename = true;
              standard = "default";
              daily = "default";
              anime = "default";
            };
          };
          quality_profiles = [
            {
							name = "WEB-2160p (Combined)";
              trash_id = "c4cadd6b35b95f62c3d47a408e53e2f7";
              reset_unmatched_scores.enabled = true;
            }
            {
              name = "Anime - Dual Audio";
              trash_id = "20e0fc959f1f1704bed501f23bdae76f";
              reset_unmatched_scores.enabled = true;
              min_format_score = 2000;
            }
					];
					custom_format_groups = {
					  add = [
					    {
					      trash_id = "e3f37512790f00d0e89e54fe5e790d1c"; # Golden Rule UHD
					      exclude = [
					        "9b64dff695c2115facf1b6ea59c9bd07" # x265 (no HDR/DV)
					      ];
					    }
					  ];
					};
					custom_formats = [
            {
              trash_ids = [
                "418f50b10f1907201b6cfdf881f467b7" # Anime Dual Audio
              ];
              assign_scores_to = [
                {
                  name = "Anime - Dual Audio";
                  score = 2001;
                }
              ];
            }
          ];
        };
        radarr.movies = {
          base_url = "http://localhost:7878";
          api_key = "!env_var RADARR_API_KEY";
          delete_old_custom_formats = false;
          quality_definition.type = "movie";
          media_naming = {
            folder = "default";
            movie = {
              rename = true;
              standard = "standard";
            };
          };
          quality_profiles = [
            {
              # WEBDL 2160p (Combined): WEB 1080p and WEB 2160p, upgrade until WEB 2160p
							name = "WEBDL 2160p (Combined)";
              trash_id = "05fbf054ac8ad0303335026cc2632f1a";
              reset_unmatched_scores.enabled = true;
            }
            {
              # [Anime] Remux-1080p, renamed. Dual audio is required via the score below.
              name = "Anime - Dual Audio";
              trash_id = "722b624f9af1e492284c4bc842153a38";
              reset_unmatched_scores.enabled = true;
              min_format_score = 2000;
            }
          ];
          # Radarr IDs differ from the Sonarr Golden Rule group. Same effect:
          # allow 1080p HEVC that is not HDR or Dolby Vision.
          custom_format_groups = {
            add = [
              {
                trash_id = "ff204bbcecdd487d1cefcefdbf0c278d"; # Golden Rule UHD
                exclude = [
                  "839bea857ed2c0a8e084f3cbdbd65ecb" # x265 (no HDR/DV)
                ];
              }
            ];
          };
          custom_formats = [
            {
              trash_ids = [
                "4a3b087eea2ce012fcc1ce319259a3be" # Anime Dual Audio
              ];
              assign_scores_to = [
                {
                  name = "Anime - Dual Audio";
                  score = 2001;
                }
              ];
            }
            {
              trash_ids = [
                "957d0f44b592285f26449575e8b1167e" # Special Edition
              ];
              assign_scores_to = [
                {
                  name = "WEBDL 2160p (Combined)";
                  score = 1000;
                }
              ];
            }
          ];
        };
      };
    };
  };

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/srv/media" ];
  systemd.services.sonarr.unitConfig.RequiresMountsFor = [ "/srv/media" ];
  systemd.services.radarr.unitConfig.RequiresMountsFor = [ "/srv/media" ];
  systemd.services.qbittorrent.unitConfig.RequiresMountsFor = [ "/srv/media" ];

  environment.systemPackages = with pkgs; [
    neovim
    git
    htop
    curl
    ghostty.terminfo
    yazi
  ];


  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";

}
