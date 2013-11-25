## About VSPi ##


[Read more about VSPi on the Village Science site.](http://villagescience.org/vs-pi/)

> VS-Pi has been designed to address every one of these obstacles:

> * It’s inexpensive. Fully assembled, we’re aiming for a cost of about US$65 per unit;
* It’s efficient. Our device needs very little electricity to operate and can run on solar power, a battery, or even a water wheel in a stream;
* It’s useful. VS-Pi comes “pre-loaded” with culturally-relevant, local language content from a variety of partners: educational texts, health videos, agricultural information, financial literacy training – all tailored to each community’s needs.

> In locations with internet access, VS-Pi does even more. It can deliver real-time data (such as weather alerts and crop prices) directly to communities. It can also allow content providers to update and refine the materials they’re providing to communities, based upon direct feedback. Users can create or improve their own materials and share it with their neighbors.

## `vspi` ##

Download the latest NOOBS from [raspberrypi.org/downloads](http://www.raspberrypi.org/downloads). NOOBS Lite (network install only) will be a smaller download since it doesn't grab the OSes until you pick one at install but if you plan to reinstall Raspbian several times, it'll have to re-download the OS each time.

Follow the instructions from the [Quick Start Guide [PDF]](http://www.raspberrypi.org/wp-content/uploads/2012/04/quick-start-guide-v2_1.pdf) to install Raspbian using NOOBS.

Once Raspbian is installed, your Pi will reboot and then go in to a blue and red config window. We don't need to do anything here so hit 'Finish' and you should be taken to the command prompt.

Run this command to install and configure VS-Pi:

    git clone https://github.com/villagescience/vspi.git && sudo bash ./vspi/setup.sh

The setup script will now run and might take over 10 minutes depending on your connection. The script sets up and configures:

* PHP
* MySQL
* nginx
* Redis
* Wordpress
* Various network utilities to make VSPi a wifi hotspot

After the script finishes, your Pi will reboot. Once it's booted back up, you can join the wireless network it creates called "VS-Pi Connect" then navigate to http://vspi.local.
