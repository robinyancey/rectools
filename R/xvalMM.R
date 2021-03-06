
# splits input data into training and test sets, fits "ydots" model on
# the former, then predicts the latter

# arguments:

#   ratingsIn: input data, with first cols (userID,itemID,rating,
#              covariates); data frame, unless cls is non-null, in which
#              case this argument is the quoted name of the distributed 
#              data frame
#   trainprop: proportion of data for the training set
#   accmeasure: accuracy measure; 'exact', 'mad', 'rms' for
#               prop of exact matches, mean absolute error, and
#               root-mean square error

# value:

#    accuracy value

xvalMM <- function(ratingsIn, trainprop=0.5, 
    haveUserCovs=FALSE, haveItemCovs=FALSE, haveBoth=FALSE) 
{
  ratIn = ratingsIn 
  # split into random training and validation sets 
  nrowRatIn = nrow(ratIn)
  rowNum = floor(trainprop * nrowRatIn)
  trainIdxs = sample(1:nrowRatIn,rowNum)
  trainingSet = ratIn[trainIdxs, ]
  trainRatings = trainingSet[,3]
  trainItems = trainingSet[,2]
  trainUsers = trainingSet[,1]
  # get means
  means = trainMM(trainingSet)
  # Y.. = means$grandMean
  # Yi. = means$usrMeans
  # Y.j = means$itmMeans
  testIdxs <- setdiff(1:nrowRatIn,trainIdxs)
  testA = ratIn[testIdxs,]
  tmp <- deleteNewIDs(testA,trainUsers,trainItems)
  testA <- tmp$testSet
  deleted <- tmp$deleted
  pred = predict(means,testA[,-3], haveUserCovs=haveUserCovs, 
     haveItemCovs=haveItemCovs, haveBoth=haveBoth)
  # calculate accuracy 
  result = list(nFullData=nrowRatIn,trainprop=trainprop,preds=pred,
     deleted=deleted)
  # accuracy measures
  exact <- mean(round(pred) == testA[,3],na.rm=TRUE)
  mad <- mean(abs(pred-testA[,3]),na.rm=TRUE)
  rms= sqrt(mean((pred-testA[,3])^2,na.rm=TRUE))
  # if just guess mean
  meanRat <- mean(testA[,3],na.rm=TRUE)
  overallexact <- 
     mean(round(meanRat) == testA[,3],na.rm=TRUE)
  overallmad <- mean(abs(meanRat-testA[,3]),na.rm=TRUE)
  overallrms <- sd(testA[,3],na.rm=TRUE)  
  result$acc <- list(exact=exact,mad=mad,rms=rms,
     overallexact=overallexact,
     overallmad=overallmad,
     overallrms=overallrms)
  result$idxs <- testIdxs
  result$preds <- pred
  result$actuals <- testA[,3]
  result$type <- 'MM'
  class(result) <- 'xvalb'
  result
}

# any users or items in test set but not the training set?
deleteNewIDs <- function(testSet,trainUsers,trainItems)
{
   deleted <- NULL  # named row numbers from the original full data
   rns <- row.names(testSet)
   tmp <- setdiff(unique(testSet[,1]),unique(trainUsers))
   if (length(tmp) > 0) {
      for (usr in tmp) {
         tmp1 <- which(testSet[,1] == usr)
         # tmp1 is ordinal row numbers within testSet; the latter may
         # have shrunken in earlier iterations!
         deleted <- c(deleted,row.names(testSet[tmp1,]))
         testSet <- testSet[-tmp1,]
      }
   }
   tmp <- setdiff(unique(testSet[,2]),unique(trainItems))
   if (length(tmp) > 0) {
      for (itm in tmp) {
         tmp1 <- which(testSet[,2] == itm)
         # tmp1 is ordinal row numbers within testSet; the latter may
         # have shrunken in earlier iterations, here or above!
         deleted <- c(deleted,row.names(testSet[tmp1,]))
         testSet <- testSet[-tmp1,]
      }
   }
   deleted <- unique(deleted)
   list(testSet = testSet, deleted = deleted)
}

# check
checkxv <- function() {
   set.seed(999999)
   check <- data.frame(
      u=sample(1:5,12,replace=TRUE),
      i=sample(11:15,12,replace=TRUE),
      r=sample(21:25,12,replace=TRUE))
   print(check) 
   xvout <- xvalMM(check,0.5)
   print(xvout$idxs)  # 1 6 7 8 11 12
   print(xvout$deleted)  # "8" "11"
   print(xvout$preds)
   print(xvout$actuals)
   check$cv = sample(31:35,12,replace=TRUE)  # covariate
   print(check)
   print(xvout)
}

# see how well covs do on small Ni users
xvSmallNi <- function(ratIn,maxN,minN) {
   ri1 <- as.character(ratIn[,1])
   NiVals <- tapply(ri1,ri1,length)
   smallNi <- which(NiVals <= maxN)
   rows <- as.numeric(names(smallNi))
   smallRatIn <- ratIn[rows,]
   xvalMM(smallRatIn,trainprop=0.8,minN = minN,haveBoth=T)$acc
}
