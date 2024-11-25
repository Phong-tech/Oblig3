#!/bin/bash


# Content-Type header for HTML
echo "Content-Type: text/html"
echo ""

# File paths
user_file="users.txt"
leaderboard_file="leaderboard.txt"
weather_cache="weather_cache.txt"

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

# Generate the HTML form
function generate_form() {
    echo "<!DOCTYPE html>"
    echo "<html>"
    echo "<head><title>Weather Guessing Game</title></head>"
    echo "<body>"
    echo "<h1>Weather Guessing Game</h1>"
    echo "<form action=\"/cgi-bin/weather_game.sh\" method=\"POST\">"
    echo "  <label for=\"city\">Select a city:</label>"
    echo "  <select name=\"city\">"
    for city in "${cities[@]}"; do
        city_name=$(echo $city | sed 's/ – .*//')
        echo "    <option value=\"$city\">$city_name</option>"
    done
    echo "  </select><br><br>"
    echo "  <label for=\"guess\">Your temperature guess (°C):</label>"
    echo "  <input type=\"number\" name=\"guess\" required><br><br>"
    echo "  <button type=\"submit\">Submit</button>"
    echo "</form>"
    echo "</body>"
    echo "</html>"
}

# Handle the POST request
function handle_post() {
    # Read POST data
    read post_data

    # Parse city and guess from POST data
    city=$(echo "$post_data" | grep -oP 'city=\K[^&]+')
    guess=$(echo "$post_data" | grep -oP 'guess=\K\d+')

    # Decode city name
    city_decoded=$(echo "$city" | sed 's/%20/ /g')

    # Fetch cached weather
    temp_actual=$(get_cached_weather "$city_decoded")

    # Validate inputs
    if ! [[ "$guess" =~ ^[0-9]+$ ]] || ! [[ "$temp_actual" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please try again."
        generate_form
        return
    fi

    # Calculate difference
    difference=$((guess - temp_actual))
    difference=${difference#-} # Get absolute value

    # Generate result page
    echo "<!DOCTYPE html>"
    echo "<html>"
    echo "<head><title>Weather Guessing Game - Result</title></head>"
    echo "<body>"
    echo "<h1>Result</h1>"
    echo "<p>City: $city_decoded</p>"
    echo "<p>Your Guess: $guess°C</p>"
    echo "<p>Actual Temperature: $temp_actual°C</p>"
    if [[ $difference -le 5 ]]; then
        echo "<p><strong>Congratulations! You guessed within 5 degrees. You win!</strong></p>"
    else
        echo "<p><strong>Sorry, you lose. Try again!</strong></p>"
    fi
    echo "<a href=\"/cgi-bin/weather_game.sh\">Play Again</a>"
    echo "</body>"
    echo "</html>"
    echo "<h1>Apache is Working!</h1>" | sudo tee /Library/WebServer/Documents/index.html
    

}





# Main CGI script logic
if [[ "$REQUEST_METHOD" == "POST" ]]; then
    handle_post
else
    generate_form
fi

