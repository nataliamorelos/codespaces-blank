library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)
library(stringr)
library(scales)

# --- Load Data ---
master <- read_csv("data/processed/master_collapsed.csv")
seasonal <- read_csv("data/processed/seasonal_color_performance.csv")
trends <- read_csv("data/processed/google_trends_clean.csv")
reddit <- read_csv("data/processed/reddit_sentiment.csv")

# --- Theme ---
theme_alo <- theme_minimal(base_size = 13) +
    theme(
        plot.title = element_text(face = "bold", size =15),
        plot.subtitle = element_text(color = "gray50", size =11),
        plot.caption = element_text(color = "gray60", size =9),
        panel.grid.minor = element_blank(),
        legend.position = "bottom"
    )

# --- Actual colors for Particl tags ---
color_palette <- c(
    "black"= "#1a1a1a",
    "white"= "#e8e8e8",
    "brown"= "#834d26",
    "grey"= "#9E9E9E",
    "blue"= "#2486e9",
    "green"= "#2e8f33",
    "pink"= "#fb73a1",
    "red"= "#c11000",
    "yellow"= "#ffd61e",
    "purple"= "#853b94",
    "orange"= "#ff5d0c"
)

# --- Plot 1: Total Revenue ---
p1 <- master %>%
    filter(!is.na(total_revenue)) %>%
    mutate(color_tag = str_to_title(color_tag)) %>%
    ggplot(aes(
        x = reorder(color_tag, total_revenue),
        y = total_revenue,
        fill = str_to_lower(color_tag)
    )) +
    geom_col(width = 0.7, show.legend = FALSE) + 
    geom_text(
        aes(label = dollar(total_revenue, scale = 1e-6, suffix = "M", accuracy = 0.1)),
        hjust = -0.1, size = 3.5
    ) + 
    coord_flip() +
    scale_fill_manual(values = color_palette) + 
    scale_y_continuous(
        labels = dollar_format(scale = 1e-6, suffix = "M"),
        expand = expansion(mult = c(0, 0.25))
    ) +
    labs(
        title = "Alo Yoga - Total Revenue by Color",
        subtitle = "Based oon Particl top 50 per color, Mar-Apr 2026",
        x = NULL, y = "Total Revenue",
        caption = "Source: Particl"
    ) +
    theme_alo

ggsave("output/plots/01_revenue_by_color.png", p1,
    width = 10, height = 7, dpi =150)

# --- Plot 2: Sell Through Rate by Color ---
p2 <- master %>%
filter(!is.na(avg_sell_through)) %>%
mutate(color_tag = str_to_title(color_tag)) %>%
ggplot(aes(
    x = reorder(color_tag, avg_sell_through),
    y = avg_sell_through,
    fill = str_to_lower(color_tag)
)) +
geom_col(width = 0.7, show.legend = FALSE) +
geom_text(
    aes(label = paste0(round(avg_sell_through, 1), "%")),
    hjust = -0.1, size = 3.5
) +
coord_flip()+
scale_fill_manual(values = color_palette)+
scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
labs(
    title = "Alo Yoga - Average Sell Through Rate by Color",
    subtitle = "Higher % = inventory sold faster = stronger demand signal",
    x = NULL,
    y = "Avg Sell Through Rate (%)",
    caption = "Source: Particl"
) +
theme_alo

ggsave("output/plots/02_sell_through_by_color.png", p2,
width = 10, height = 7, dpi = 150)

# --- Plot 3: Search Interest Heatmap by Color and Season ---
trends_heat <- trends %>%
    filter(keyword != "Alo Yoga") %>%
    mutate(
        color_tag = str_to_title(str_remove(keyword, "Alo Yoga")),
        season = factor(season, levels = c("Spring", "Summer", "Fall", "Winter"))
    ) %>%
    group_by(color_tag, season) %>%
    summarize(avg_interest = round(mean(interest), 1), .groups = "drop")

p3 <- trends_heat %>%
    ggplot(aes(x = season, y = reorder(color_tag, avg_interest),
        fill = avg_interest)) +
    geom_tile(color = "white", linewidth = 0.5) +
    geom_text(aes(label = avg_interest), size = 3.5, color = "white") +
    scale_fill_gradient(low = "#f5f5f5", high = "#1a237e") +
    labs(
        title = "Alo Yoga - Seasonal Search Interest by Color",
        subtitle = "Google Trends 5 Year Average (0-100 scale)",
        x = NULL, y= NULL,
        fill = "Avg Interest",
        caption = "Source: Google Trends US, 2021-26"
    ) +
    theme_alo +
    theme(legend.position = "right")

ggsave("output/plots/03_seasonal_search_heatmap.png", p3,
    width = 10, height = 7, dpi = 150)

# --- Plot 4: Reddit Sentiment by Color ---
reddit_summary <- reddit %>%
    group_by(color) %>%
    summarize(
        avg_polarity = mean(polarity, na.rm = TRUE),
        post_count = n(),
        .groups = "drop"
    ) %>%
    mutate(
        sentiment_label = case_when(
            avg_polarity > 0.05 ~ "Positive",
            avg_polarity < ~ 0.04 ~ "Negative",
            TRUE ~ "Neutral"
       ),
       color_title = str_to_title(color)
    )

p4 <- reddit_summary %>%
    ggplot(aes(
        x = reorder(color_title, avg_polarity),
        y = avg_polarity,
        fill = str_to_lower(color)
    )) +
    geom_col(width = 0.7, show.legend = FALSE) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray40")+
    geom_text(
        aes(
            label = round(avg_polarity, 3),
            hjust = if_else(avg_polarity >= 0, -0.1, 1.1)
        ),
        size = 3.5
    ) +
    coord_flip() +
    scale_fill_manual(values = color_palette) +
    scale_y_continuous(expand = expansion(mult = c(0.2, 0.2))) +
    labs(
        title = "Alo Yoga: Reddit Sentiment by Color",
        subtitle = "r/aloyoga posts and comments (polarity score -1 to +1)",
        x = NULL, y= "Avg Sentiment Polarity",
        caption = "Source:Reddit r/aloyoga via PullPush.io"
    ) +
    theme_alo

ggsave("output/plots/04_reddit_sentiment.png", p4,
    width = 10, height = 7, dpi = 150)

# --- Plot 4: Top Colors per season heatmap ---
p5 <- seasonal %>%
    mutate(
        particl_color_tag = str_to_title(particl_color_tag),
        release_season = factor(
            release_season, levels = c("Spring", "Summer", "Fall", "Winter"))
    ) %>%
    ggplot(aes(
        x = release_season,
        y = reorder(particl_color_tag, avg_revenue),
        fill = avg_revenue
    )) +
    geom_tile(color = "white") +
    geom_text(
        aes(label = dollar(avg_revenue, scale = 1e-3, suffix = "K", accuracy = 1)),
        size = 3, color = "white"
    ) +
    scale_fill_gradient(
        low = "#fff9c4",
        high = "#e65100",
        labels = dollar_format(scale = 1e-3, suffix = "K")
    ) +
    labs(
        title = "Alo Yoga: Average Revenue by Color and Season Released",
        subtitle = "Based on season product was first listed", 
        x= NULL, y= NULL,
        fill = "Avg Revenue",
        caption = "Source: Particl"
    ) +
    theme_alo + theme(legend.position = "right")

ggsave("output/plots/5_seasonal_color_revenue.png", p5,
width = 10, height = 8, dpi = 150)

# --- Plot 6: Final Prediction Scores ---
p6 <- master %>%
    filter(!is.na(prediction_score)) %>%
    mutate(
        color_title = str_to_title(color_tag),
        bar_label = paste0(prediction_score, " / 100")
    ) %>%
    ggplot(aes(
        x = reorder(color_title, prediction_score),
        y = prediction_score,
        fill = str_to_lower(color_tag)
    )) +
    geom_col(width = 0.7, show.legend = FALSE) +
    geom_text(
        aes(label = bar_label),
        hjust = -0.1, size = 3.5, fontface = "bold"
    ) +
    coord_flip()+
    scale_fill_manual(values = color_palette) +
    scale_y_continuous(
        limits = c(0,100),
        expand = expansion(mult = c(0,0))
    ) +
    labs(
        title = "Alo Yoga: Summer 2026 Color Prediction Score",
        subtitle = "Composite Score: Revenue (35%) + Sell Through (25%) + Search Trends (20%) + Sentiment (10%) + Season Fit (10%)",
        x = NULL, y = "Prediction Score (0-100)",
        caption = "Sources: Particl, Google Trends, Reddit r/aloyoga"
    ) +
    theme_alo

ggsave("output/plots/6_color_prediction.png", p6,
    width = 11, height = 7, dpi = 150)
