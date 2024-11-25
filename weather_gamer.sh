#!/bin/bash


# File paths
user_file="users.txt"
leaderboard_file="leaderboard.txt"
weather_cache="weather_cache.txt"

# Function to create Apache test page
function create_apache_test_page() {
    echo "Creating Apache test page..."
    echo "<!DOCTYPE html>
<html>
<head><title>Apache Test</title></head>
<body>
    <h1>Apache is Working!</h1>
</body>
</html>" | sudo tee /Library/WebServer/Documents/index.html > /dev/null

echo "<h1>Apache is Working!</h1>" | sudo tee /Library/WebServer/Documents/index.html


    echo "Test page created at http://localhost."
}

# Function to cache weather data
function cache_weather_data() {
    > "$weather_cache"
    for city in "${cities[@]}"; do
        city_url=$(echo $city | sed 's/ – .*//;s/ /%20/g') # Encode city name for URL
        temp=$(curl -s "http://wttr.in/${city_url}?format=%t" | tr -dc '0-9-')
        echo "$city:$temp" >> "$weather_cache"
    done
}

# Main script setup
echo "Checking Apache setup..."
create_apache_test_page


# Initialize files if not present
if [[ ! -f "$user_file" ]]; then
    touch "$user_file"
fi

if [[ ! -f "$leaderboard_file" ]]; then
    touch "$leaderboard_file"
fi

if [[ ! -f "$weather_cache" ]]; then
    > "$weather_cache"
fi

# List of European cities
cities=(
    "London – United Kingdom" "Paris – France" "Berlin – Germany"
    "Rome – Italy" "Madrid – Spain" "Amsterdam – Netherlands"
    "Brussels – Belgium" "Vienna – Austria" "Athens – Greece"
    "Lisbon – Portugal" "Stockholm – Sweden" "Copenhagen – Denmark"
    "Oslo – Norway" "Warsaw – Poland" "Helsinki – Finland"
    "Prague – Czech Republic" "Budapest – Hungary"
    "Bucharest – Romania" "Dublin – Ireland" "Zagreb – Croatia"
)

# Function to register a new user
function register_user() {
    echo "Register a new account:"
    read -p "Username: " username
    read -sp "Password: " password
    echo
    read -p "Preferred temperature unit (C/F): " unit

    if grep -q "^$username:" "$user_file"; then
        echo "Username already exists. Please try logging in."
        return 1
    fi

    echo "$username:$password:$unit" >> "$user_file"
    echo "Registration successful. Please log in."
}

# Function to log in an existing user
function login_user() {
    echo "Login to your account:"
    read -p "Username: " username
    read -sp "Password: " password
    echo

    # Verify credentials
    user_data=$(grep "^$username:$password:" "$user_file")
    if [[ -z "$user_data" ]]; then
        echo "Invalid username or password. Try again."
        return 1
    fi

    unit=$(echo "$user_data" | cut -d':' -f3)
    echo "Welcome, $username! Preferred unit: $unit"
}

# Function to update the leaderboard
function update_leaderboard() {
    user=$1
    diff=$2
    total=$(grep "^$user:" "$leaderboard_file" | cut -d':' -f2)
    plays=$(grep "^$user:" "$leaderboard_file" | cut -d':' -f3)

    # Update or initialize stats
    if [[ -z "$total" ]]; then
        total=$diff
        plays=1
    else
        total=$((total + diff))
        plays=$((plays + 1))
    fi

    avg=$((total / plays))
    sed -i "/^$user:/d" "$leaderboard_file" 2>/dev/null
    echo "$user:$total:$plays:$avg" >> "$leaderboard_file"
}

# Display the leaderboard
function show_leaderboard() {
    echo "Leaderboard:"
    sort -t':' -k4 -n "$leaderboard_file" | while IFS=: read -r user total plays avg; do
        echo "$user - Average Difference: $avg°C, Plays: $plays"
    done
}

# Cache weather data
function cache_weather_data() {
    > "$weather_cache"
    for city in "${cities[@]}"; do
        city_url=$(echo $city | sed 's/ – .*//;s/ /%20/g') # Encode city name for URL
        temp=$(curl -s "http://wttr.in/${city_url}?format=%t" | tr -dc '0-9-')
        echo "$city:$temp" >> "$weather_cache"
    done
}

# Fetch weather from cache
function get_cached_weather() {
    city=$1
    grep "^$city:" "$weather_cache" | cut -d':' -f2
}

# Main game logic
function play_game() {
    city="${cities[$((RANDOM % ${#cities[@]}))]}"
    echo "Guess the current temperature in $city (in $unit):"
    read -p "Your guess: " guess

    # Fetch cached weather
    temp_actual=$(get_cached_weather "$city")

    # Debugging output
    echo "Debug: City = $city, Actual Temperature = $temp_actual"

    # Ensure numeric values for arithmetic
    if ! [[ $guess =~ ^-?[0-9]+$ ]] || ! [[ $temp_actual =~ ^-?[0-9]+$ ]]; then
        echo "Error: Invalid input. Please ensure both the guess and temperature are numbers."
        return
    fi

    # Convert temperature to Fahrenheit if needed
    if [[ "$unit" == "F" ]]; then
        temp_actual=$(( (temp_actual * 9 / 5) + 32 ))
    fi

    # Calculate difference
    difference=$((guess - temp_actual))
    difference=${difference#-}  # Get absolute value

    # Determine result
    if [[ $difference -le 5 ]]; then
        echo "Congratulations! You guessed within 5 degrees. You win!"
    else
        echo "Sorry, you lose. The actual temperature in $city is $temp_actual°$unit."
    fi

    # Update leaderboard
    update_leaderboard "$username" "$difference"
}

# Main script execution
echo "Welcome to the Weather Guessing Game!"
echo "1. Login"
echo "2. Register"
read -p "Choose an option: " option

if [[ "$option" == "1" ]]; then
    while ! login_user; do :; done
elif [[ "$option" == "2" ]]; then
    while ! register_user; do :; done
    login_user
else
    echo "Invalid option. Exiting."
    exit 1
fi

# Cache weather data before starting the game
cache_weather_data

while true; do
    play_game
    read -p "Do you want to play again? (yes/no): " play_again
    if [[ "$play_again" != "yes" ]]; then
        echo "Thanks for playing! Goodbye."
        break
    fi
done

# Show leaderboard at the end
show_leaderboard
