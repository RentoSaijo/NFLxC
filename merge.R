test1 <- read.csv('data/contracts_2012.csv')
test2 <- read.csv('data/contracts_2012.csv')
test3 <- read.csv('data/contracts_2013.csv')
test4 <- read.csv('data/contracts_2014.csv')
test5 <- read.csv('data/contracts_2015.csv')
test6 <- read.csv('data/contracts_2016.csv')
test7 <- read.csv('data/contracts_2017.csv')
test8 <- read.csv('data/contracts_2018.csv')
test9 <- read.csv('data/contracts_2019.csv')
test10 <- read.csv('data/contracts_2020.csv')
test11 <- read.csv('data/contracts_2021.csv')
test12 <- read.csv('data/contracts_2022.csv')
test13 <- read.csv('data/contracts_2023.csv')
test14 <- read.csv('data/contracts_2024.csv')
test15 <- read.csv('data/contracts_2025.csv')
test16 <- read.csv('data/contracts_2026.csv')


all_contracts <- data.frame()
for(year in 2012:2026) {
  file_name <- paste0('data/contracts_', year, '.csv')
  temp_data <- read.csv(file_name)
  all_contracts <- rbind(all_contracts, temp_data)
}
dim(all_contracts)
View(all_contracts)
summary(all_contracts)

write.csv(all_contracts, 'data/contracts.csv')