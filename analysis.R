library(ggplot2)

mpg <- readRDS("mpg.rds")

# explore
ggplot(mpg) +
  aes(x = cyl, y = hwy) +
  geom_jitter(width = 0.1, height = 0)

ggplot(mpg) +
  aes(x = class, y = hwy) +
  geom_jitter(width = 0.1, height = 0)

summary(mpg$hwy)
hist(mpg$hwy)

# linear model
m <- lm(hwy ~ cyl + class, data = mpg)
summary(m)
confint(m)
drop1(m, test = "F")

# diagnostics
plot(m)

# sensitivity analysis: hold out three possibly influential records
k <- c(223, 222, 213)
m2 <- lm(hwy ~ cyl + class, data = mpg[-k,])
summary(m2)
plot(m2)

# all three are volkswagen with very high mpg
mpg[k,]
