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
    # The leading 2 in 2775 makes subdirectories inherit the group of the parent directory
    "d /srv/zotero                     2770 root zotero -"
    "d /srv/media                      2775 root media -"
    "d /srv/media/movies               2775 root media -"
    "d /srv/media/shows                2775 root media -"
    "d /srv/media/books                2775 root media -"
    "d /srv/media/manga                2775 root media -"
    "d /srv/media/music                2775 root media -"
    "d /srv/media/downloads            2775 root media -"
    "d /srv/media/downloads/incomplete 2775 root media -"
    "d /srv/media/downloads/complete   2775 root media -"
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

    jellyfin.extraGroups    = [ "media" ];
    qbittorrent.extraGroups = [ "media" ];
    radarr.extraGroups      = [ "media" ];
    sonarr.extraGroups      = [ "media" ];
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

  services.qbittorrent = {
    enable = true;
    openFirewall = true;   # :8080
    torrentingPort = 6881;
    extraArgs = [ "--confirm-legal-notice" ];

    serverConfig = {
      LegalNotice.Accepted = true;
      BitTorrent = {
        Session = {
          DefaultSavePath = "/srv/media/downloads/complete";
          TempPathEnabled = true;
          TempPath = "/srv/media/downloads/incomplete";
        };
      };
      Preferences = {
      WebUI = {
        Username = "bbarnhart";
        Password_PBKDF2 = "@ByteArray(zfkioBnV+p4yAfohG1b1UA==:JLsPOq5scIA1srkMoXs/Fv+kb0UMXoQKYJx1hGSCBNVsh1ZrH+dcVrFUB8weHxT8FRivOAsxz6hGrQS8bHTTrw==)";
      };
    };
    };
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;  # :8096
  };

  systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/srv/media" ];

  services.prowlarr = {
    enable = true;
    openFirewall = true;   # :9696
  };

  services.radarr = {
    enable = true;
    openFirewall = true;   # :7878
  };

  services.sonarr = {
    enable = true;
    openFirewall = true;   # :8989
  };

  services.seerr = {
    enable = true;
    openFirewall = true;   # :5055
  };

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
