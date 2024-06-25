
#install.packages("spData")
install.packages("canadianmaps")
library(spData)
library(canadianmaps)

# see how many fall in US OR Canada
# Transform CRS if they do not match
if (st_crs(zero_pop_crashes) != st_crs(us_states)) {
  zero_pop_crashes <- st_transform(zero_pop_crashes, crs = st_crs(us_states))
}
# Perform spatial join
intersections <- st_intersects(zero_pop_crashes, us_states)
# Count points within any U.S. state
num_points_in_us <- sum(sapply(intersections, any))
print(num_points_in_us)


#canada
if (st_crs(zero_pop_crashes) != st_crs(REG)) {
  zero_pop_crashes <- st_transform(zero_pop_crashes, crs = st_crs(REG))
}
sf_use_s2(FALSE)
intersections_can <- st_intersects(zero_pop_crashes, REG)

# Count points within any Canada
num_points_in_can <- sum(sapply(intersections_can, any))
print(intersections_can)

# zero points
