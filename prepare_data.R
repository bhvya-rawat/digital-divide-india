# prepare_data.R
# Run ONCE on your own computer. Reads the big raw NSS CAMS CSVs (kept out of
# GitHub) and writes two small analysis files into data/ that the report uses.
#
# Put the raw files in data-raw/ :
#   NSS79CAMS_Household.csv, NSS79CAMS_Member.csv, NSS79CAMS_Course.csv
# Source: MoSPI, NSS 79th Round (CAMS, 2022-23) unit-level data.

library(tidyverse)
library(here)

raw <- function(f) read.csv(here("data-raw", f))
cams_households <- raw("NSS79CAMS_Household.csv")
cams_member     <- raw("NSS79CAMS_Member.csv")
cams_course     <- raw("NSS79CAMS_Course.csv")

# Keys must be unique or the joins below would silently duplicate rows
stopifnot(
  nrow(cams_households) == nrow(distinct(cams_households, FSU, SSS, SSU)),
  nrow(cams_member)     == nrow(distinct(cams_member, FSU, SSS, SSU, SRL))
)

# Survey weight: readme_CAMS says weight = MULT / 100
cams_households <- mutate(cams_households, weight = MULT / 100)
cams_member     <- mutate(cams_member,     weight = MULT / 100)

# ---- Households -------------------------------------------------------------
head_sex_lookup <- cams_member |>
  filter(BL31C3 == 1) |>
  transmute(FSU, SSS, SSU,
            head_sex = factor(BL31C4, levels = 1:3,
                              labels = c("Male", "Female", "Transgender")))

weighted_quantile <- function(x, w, probs) {
  keep <- !is.na(x) & !is.na(w)
  x <- x[keep]; w <- w[keep]
  ord <- order(x); x <- x[ord]; w <- w[ord]
  cum_w <- cumsum(w) / sum(w)
  vapply(probs, function(p) x[which.max(cum_w >= p)], numeric(1))
}

q_labels <- c("Q1\n(poorest)", "Q2", "Q3", "Q4", "Q5\n(richest)")

households <- cams_households |>
  left_join(head_sex_lookup, by = c("FSU", "SSS", "SSU")) |>
  mutate(
    has_mobile   = if_else(replace_na(BL42I1II, 0) > 0, "Yes", "No"),
    has_computer = if_else(replace_na(BL42I1III, 0) > 0 |
                             replace_na(BL42I1IV, 0) > 0, "Yes", "No"),
    has_internet = if_else(BL42I2 == 1, "Yes", "No"),
    stratum_1    = interaction(STRM, SSTRM, drop = TRUE),
    mpce         = BL6I6 / BL41I1,          # monthly per capita expenditure
    sector       = factor(SEC, levels = 1:2, labels = c("Rural", "Urban"))
  )

cuts <- weighted_quantile(households$mpce, households$weight,
                          c(0.2, 0.4, 0.6, 0.8))
households <- households |>
  mutate(mpce_quintile = cut(mpce, c(-Inf, cuts, Inf), labels = q_labels)) |>
  select(FSU, SSS, SSU, stratum_1, weight, head_sex, sector,
         has_mobile, has_computer, has_internet, mpce, mpce_quintile)

# ---- Members (adults 15+, Male/Female only) ---------------------------------
has_course_record <- cams_course |>
  distinct(FSU, SSS, SSU, SRL) |>
  mutate(has_course = "Yes")

members <- cams_member |>
  mutate(
    sex = factor(BL31C4, levels = 1:3, labels = c("Male", "Female", "Transgender")),
    age = BL31C5,
    mobile_smartphone = if_else(BL32C3 == 1, 1, 0),
    can_use_internet  = if_else(BL32C7 %in% c(1, 2, 3), 1, 0),
    can_email         = if_else(BL32C9 == 1, 1, 0),
    can_digital_bank  = if_else(BL32C10 == 1, 1, 0),
    economically_active = if_else(BL31C8 == 1, "Yes", "No"),
    stratum_1 = interaction(STRM, SSTRM, drop = TRUE)
  ) |>
  # Blank = question skipped because an earlier answer was "no" -> code as 0
  mutate(across(c(mobile_smartphone, can_use_internet, can_email,
                  can_digital_bank), ~ replace_na(.x, 0))) |>
  left_join(select(households, FSU, SSS, SSU, mpce, mpce_quintile, sector),
            by = c("FSU", "SSS", "SSU")) |>
  left_join(has_course_record, by = c("FSU", "SSS", "SSU", "SRL")) |>
  mutate(has_course = replace_na(has_course, "No")) |>
  filter(age >= 15, sex %in% c("Male", "Female")) |>
  mutate(sex = droplevels(sex)) |>
  select(FSU, stratum_1, weight, sex, age, sector, mpce, mpce_quintile,
         mobile_smartphone, can_use_internet, can_email, can_digital_bank,
         economically_active, has_course)

saveRDS(households, here("data", "cams_households.rds"), compress = "xz")
saveRDS(members,    here("data", "cams_members.rds"),    compress = "xz")

cat("households:", nrow(households), " members (15+, M/F):", nrow(members), "\n")
print(file.size(list.files(here("data"), full.names = TRUE)) / 1e6)  # MB
