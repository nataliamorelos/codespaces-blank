library(dplyr)
library(readr)
library(stringr)
library(lubridate)
library(tidyr)

# --- Load datasets ---
particl <- read_csv("data/processed/particl_all_colors_clean.csv")
trends <- read_csv("data/processed/google_trends_clean.csv")
reddit <- read_csv("data/processed/reddit_sentiment.csv")

message("Particl rows: ", nrow(particl))
message("Trends rows: ", nrow(trends))
message("Reddit rows: ", nrow(reddit))

#---------------------------------------------------

# --- Summarize sales by color ---

particl_summary <- particl %>%
    group_by(particl_color_tag, tone_group) %>%
    summarize(
        product_count = n(),
        total_revenue = sum(sales_revenue, na.rm = TRUE),
        avg_revenue = mean(sales_revenue, na.rm = TRUE),
        avg_sell_through = mean(sell_through_pct, na.rm = TRUE),
        avg_discount = mean(avg_discount, na.rm = TRUE),
        avg_price = mean(avg_current_price, na.rm = TRUE),
        avg_rating = mean(avg_rating , na.rm = TRUE),
        total_volume = sum(sales_volume, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    mutate(
        revenue_per_product = round(total_revenue / product_count, 0),
        color_tag = str_to_lower(particl_color_tag)
    )

print(particl_summary)

#---------------------------------------------------

# --- Summarize Google Trends by color and season

trends_summary <- trends %>%
    filter(keyword != "Alo Yoga") %>%
    mutate(
        color_tag = str_to_lower(
            str_remove(keyword, "Alo Yoga ")
        )
    ) %>%
    group_by(color_tag, season) %>%
    summarize(
        avg_interest = round(mean(interest, na.rm = TRUE), 2),
        .groups = "drop"
    ) %>%

# Pivot so each season has respective column

pivot_wider(
    names_from = season,
    values_from = avg_interest,
    names_prefix = "trends_"
) %>%
mutate(
    # Best season based on highest avg interest
    best_search_season = case_when(
        pmax(trends_Spring, trends_Summer, trends_Fall, trends_Winter, na.rm = TRUE) == trends_Spring ~ "Spring",
        pmax(trends_Spring, trends_Summer, trends_Fall, trends_Winter, na.rm = TRUE) == trends_Spring ~ "Summer",
        pmax(trends_Spring, trends_Summer, trends_Fall, trends_Winter, na.rm = TRUE) == trends_Spring ~ "Fall",
        pmax(trends_Spring, trends_Summer, trends_Fall, trends_Winter, na.rm = TRUE) == trends_Spring ~ "Winter",
        TRUE ~ "Unknown"
    ),
    peak_search_interest = pmax(
        trends_Spring, trends_Summer, trends_Fall, trends_Winter, na.rm = TRUE
    )
)

print(trends_summary)

#---------------------------------------------------

# --- Summarize Reddit sentiment by color ---
reddit_summary <- reddit %>%
    group_by(color) %>%
    summarize(
        avg_polarity = round(mean(polarity, na.rm = TRUE), 3),
        avg_subjectivity = round(mean(subjectivity, na.rm = TRUE), 3),
        post_count = n(),
        positive_pct = round(mean(sentiment == "positive") * 100, 1),
        neutral_pct = round(mean(sentiment == "neutral") * 100, 1),
        negative_pct = round(mean(sentiment == "negative") * 100, 1),
        .groups = "drop"
    ) %>%
    rename(color_tag = color) %>%
    mutate(
        sentiment_label = case_when(
            avg_polarity > 0.05 ~ "Positive",
            avg_polarity < -0.05 ~ "Negative",
            TRUE ~ "Neutral"
        )
      )
    
print(reddit_summary)

#---------------------------------------------------

# --- Master dataset ---
master <- particl_summary %>%
    left_join(trends_summary, by = "color_tag") %>%
    left_join(reddit_summary, by = "color_tag") %>%
    arrange(desc(total_revenue))

# --- Preview ---
master %>%
    select(
        color_tag, total_revenue, avg_sell_through, best_search_season, peak_search_interest, avg_polarity, sentiment_label
) %>%
print(n = 20)

write_csv(master, "data/processed/master_color_analysis.csv")
message("Saved master_color_analysis.csv")

#---------------------------------------------------

# --- Which colors perform best in each season ---

seasonal_performance <- particl %>%
group_by(release_season, particl_color_tag) %>%
summarize(
    product_count = n(), 
    avg_revenue = round(mean(sales_revenue, na.rm = TRUE), 0), 
    avg_sell_through = round(mean(sell_through_pct, na.rm = TRUE), 2), 
    avg_rank = mean(sales_volume, na.rm = TRUE), 
    .groups = "drop"
) %>%
filter(release_season != "Unknown") %>%
arrange(release_season, desc(avg_revenue))

cat("\n--- Top color per season by avg revenue ---\n")
seasonal_performance %>%
group_by(release_season) %>%
slice_max(avg_revenue, n =3) %>%
print(n=50)

write_csv(seasonal_performance, "data/processed/seasonal_color_performance.csv")
message("Saved seasonal_color_performance.csv")

#---------------------------------------------------

# --- Score each color for next season recommendation ---
# Current month is April/Spring
# Next season = Summer

next_season <- "Summer"

prediction <- master %>%
    mutate(
        #Normalize each metric to 0-100 scale
        revenue_score = round(
            (total_revenue / max(total_revenue, na.rm = TRUE)) * 100, 1),
        
        sellthrough_score = round(
            (avg_sell_through / max(avg_sell_through, na.rm = TRUE)) * 100, 1),
        
        trends_score = round(
            (peak_search_interest / max(peak_search_interest, na.rm = TRUE)) * 100, 1),
        
        sentiment_score = round(
            ((avg_polarity +1) / 2) * 100, 1), 
        
        season_bonus = if_else(best_search_season == next_season, 10, 0),

        #Final weighted prediction score
        #Revenue = 35%, Sell Through = 25%, Trends = 20%, Sentiment = 10%, Season Bonus = 10%
        prediction_score = round(
            (revenue_score * 0.35) +
            (sellthrough_score * 0.25) +
            (trends_score * 0.20) +
            (sentiment_score * 0.10) +
            season_bonus,
            1
        )
    ) %>%
    arrange(desc(prediction_score)) %>%
    select(
        color_tag, prediction_score, revenue_score, sellthrough_score, trends_score, sentiment_score, season_bonus, best_search_season, sentiment_label, total_revenue, avg_sell_through
    )

cat("\n Color Prediction Scorers For", next_season, "---\n")
print(prediction, n = 20)

write_csv(prediction, "data/processed/color_predictions.csv")
message("Saved color_predictions.csv")

# --- Edit: Collapse duplicate color rows that split across tone groups ---

master_collapsed <- master %>%
    group_by(color_tag) %>%
    summarize( 
        total_revenue = sum(total_revenue, na.rm = TRUE), 
        avg_sell_through = mean(avg_sell_through, na.rm = TRUE), 
        avg_discount = mean(avg_discount, na.rm = TRUE), 
        avg_price = mean(avg_price, na.rm = TRUE), 
        product_count = sum(product_count, na.rm = TRUE), 
        trends_Spring = first(na.omit(trends_Spring)), 
        trends_Summer = first(na.omit(trends_Summer)), 
        trends_Fall = first(na.omit(trends_Fall)), 
        trends_Winter = first(na.omit(trends_Winter)), 
        best_search_season = first(na.omit(best_search_season)), 
        peak_search_interest = first(na.omit(peak_search_interest)), 
        avg_polarity = first(na.omit(avg_polarity)), 
        sentiment_label = first(na.omit(sentiment_label)), 
        .groups = "drop"
    ) %>%
    mutate( 
        revenue_per_product = round(total_revenue / product_count, 0),
    
    # Rebuild prediction score on clean data
    revenue_score      = round((total_revenue / max(total_revenue, na.rm = TRUE)) * 100, 1),
    sellthrough_score  = round((avg_sell_through / max(avg_sell_through, na.rm = TRUE)) * 100, 1),
    trends_score       = round((peak_search_interest / max(peak_search_interest, na.rm = TRUE)) * 100, 1),
    sentiment_score    = round(((avg_polarity + 1) / 2) * 100, 1),
    season_bonus       = if_else(best_search_season == "Summer", 10, 0),
    
    prediction_score   = round(
      (revenue_score     * 0.35) +
      (sellthrough_score * 0.25) +
      (trends_score      * 0.20) +
      (sentiment_score   * 0.10) +
      season_bonus,
      1
    )
  ) %>%
  arrange(desc(prediction_score))
  cat("\n FINAL PREDICTION SCORES FOR SUMMER (CLEAN) ---\n")
print(master_collapsed %>%
  select(color_tag, prediction_score, revenue_score,
         sellthrough_score, trends_score, sentiment_score,
         season_bonus, best_search_season, sentiment_label),
  n = 11)

write_csv(master_collapsed, "data/processed/master_collapsed.csv")
message("Saved master_collapsed.csv")