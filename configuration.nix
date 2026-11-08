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
              # TRaSH WEB-1080p
              trash_id = "72dae194fc92bf828f32cde7744e51a1";
              reset_unmatched_scores.enabled = true;
            }
            {
              # TRaSH [Anime] Remux-1080p
              trash_id = "20e0fc959f1f1704bed501f23bdae76f";
              reset_unmatched_scores.enabled = true;
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
              # TRaSH HD Bluray + WEB
              trash_id = "d1d67249d3890e49bc12e275d989a7e9";
              reset_unmatched_scores.enabled = true;
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
