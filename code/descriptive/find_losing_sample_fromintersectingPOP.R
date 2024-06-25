

find_differences <- function(df1, df2, pk) {
  # Check if the primary key column exists in both data frames
  if (!all(c(pk) %in% colnames(df1)) || !all(c(pk) %in% colnames(df2))) {
    stop("Primary key column not found in both data frames")
  }
  
  # Find rows in df1 not in df2
  df1_not_in_df2 <- df1[!df1[[pk]] %in% df2[[pk]], ]
  
  # Find rows in df2 not in df1
  df2_not_in_df1 <- df2[!df2[[pk]] %in% df1[[pk]], ]
  
  # Combine the results
  differences <- list(
    in_df1_not_in_df2 = df1_not_in_df2,
    in_df2_not_in_df1 = df2_not_in_df1
  )
  
  return(differences)
}


result <- find_differences(Canada_filtered, all_Canada, "pk")
print(result)
df <- result[[1]]
# checking in ArcGIS - some are on bridge - does not belong to any blocks
# some are falling out out the extent of census blocks

write.csv(, file="examineMissingPpoint.csv")
