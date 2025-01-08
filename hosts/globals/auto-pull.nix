{ config, ... }: {

  # Enable cron service
  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * *      temhr    /home/temhr/nixlab/bin/auto-pull.sh"
    ];
  };

}
