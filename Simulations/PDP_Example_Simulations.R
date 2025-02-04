library(mlr)
library(ggplot2)

PlotPartialDependanceExample<-function(visualize = FALSE, seed = 1) {
  
  set.seed(seed)
  
  

    
  
  
  # Function plotting the PDP from the data
  PlotPartialDependance<-function(pd.plot, feature.chosen.name, title = "No title assigned"){
    
    # remove the lr model
    index.remove = which(names(pd.plot) == "probalr.model")
    pd.plot = pd.plot[-index.remove]
    
    # convert to long format
    library(reshape2)
    pd.plot.long <- melt(pd.plot, id=feature.chosen.name[1])  

    detach("package:reshape2", unload=TRUE)
    
    names(pd.plot.long)[c(2,3)] = c("Algorithm", "Probability")

    plot.PartialDependanceData<-ggplot(data=pd.plot.long,
                                       aes_string(x=feature.chosen.name, y="Probability", colour="Algorithm")) +
      geom_line(data = pd.plot.long, aes(linetype = Algorithm) ,size=1) + 
      scale_linetype_manual(values=c("solid", "dotted","dashed")) +
      labs(y="Probability") +
      xlim(-3,3)
  }
  
  
  PdpAnalysis= function(n, gridsize = 20,
                        visualize=FALSE,
                        feature.chosen.name, dataset.number) {
    
    ## Data Generation
    
    # Raw gaussian distribution
    X1<-rnorm(n)
    X2<-rnorm(n)
    
    # Adapt to model chosen
    # Model 1 is standard linearity
    if (dataset.number==1) {
      Beta1=c(1, 5, -2)
      X=cbind(1,X1,X2)
      product=X%*%Beta1
    }
    # Model 2 is interraction
    if (dataset.number==2) {
      Beta2=c(-6,-10, 10)
      Beta2.12=20
      X=cbind(1,X1,X2)
      product=X%*%Beta2+Beta2.12*X1*X2
    }
    # Model 3 is non-linearity
    if (dataset.number==3) {
      Beta3=c(-2, 5)
      X=cbind(1,X1^2)
      product=X%*%Beta3
    }
    
    Y<-as.factor(rbinom(n,1,prob = plogis(product)))
    df<-data.frame(X1,X2,Y)
    classif.task<-makeClassifTask(data = df, target="Y")
    
    # Visualization of the generated datas
    plot.data <- ggplot(data=df, aes(x=X1, y=X2, colour=Y, shape = Y))
    plot.data <- plot.data + geom_point(size=2) 
    plot.data = plot.data + scale_colour_grey(start = 0,end = 0.6)+ 
      ylim(-4,4) + xlim(-4,4)

    if (visualize==TRUE) {
      print(plot.data)
    }
    
    # Checking of PartialDependance_difference.R
    # source("Simulations/PartialDependance_difference.R")
    # res.pdp.difference = getPdpDifference(classif.task, seed=1, visualize = TRUE, progression_bar = FALSE)
    # print(paste("All features",res.pdp.difference$all))
    # print(paste("3 most important features",res.pdp.difference$first3))
    
    ## Partial dependance plots
    # Parameters
    individual=FALSE
    derivative=FALSE
    interaction=FALSE
    fun=mean
    task=classif.task
    fmin=list(feature = qnorm(0.01))
    names(fmin) = feature.chosen.name
    fmax=list(feature = qnorm(0.99))
    names(fmax) = feature.chosen.name
    
    
    # The models
    # rf
    lrn.classif.rf = makeLearner("classif.randomForest", predict.type = "prob")
    fit.classif.rf = train(lrn.classif.rf, task)
    # lr
    lrn.classif.lr = makeLearner("classif.multinom", predict.type = "prob")
    fit.classif.lr = train(lrn.classif.lr, task)
    
    # Grids and generation of data for the learners already implemented in mlr
    #pd.rf = generatePartialDependenceData(fit.classif.rf, task, feature.chosen.name[1], 
    #                                      gridsize = gridsize, individual = individual, 
    #                                      derivative = derivative, interaction = interaction, 
    #                                      fun=fun, fmin = fmin, fmax=fmax)
    
    pd.rf = generatePartialDependenceData(fit.classif.rf, task, feature.chosen.name[1], 
                                          individual = individual, n=c(gridsize,200),
                                          derivative = derivative, interaction = interaction, 
                                          fun=fun)
    
    plotPartialDependence(pd.rf)
    pd.lr = generatePartialDependenceData(fit.classif.lr, task, feature.chosen.name[1], 
                                          individual = individual, n=c(gridsize,200),
                                          derivative = derivative, interaction = interaction, 
                                          fun=fun)
    
    pd.plot<-data.frame( feature = pd.rf$data[[feature.chosen.name]], 
                         RF = pd.rf$data[["0"]], 
                         LR = pd.lr$data[["0"]])
    names(pd.plot)[1]<-feature.chosen.name[1]
    
    
    
    
    # Logistic Regression learners implemented by hand
    # depending of the chosen data set and associated model
    
    if (dataset.number==1) {
      
      # The two LR learners
      mylogit <- glm(Y ~ X1+X2, data = df, family = "binomial")
      mylogit.true<-mylogit
      mylogit.true$coefficients<-Beta1
      
      # For the model with estimated parameters
      pred<-predict(mylogit, newdata = df, type = "response")
      resolution=gridsize
      
      vectX1<-(seq(as.double(fmin),as.double(fmax),length.out = resolution))
      cbind(X2,vectX1[1])
      
      df.ind<-data.frame()
      indexObservation<-seq(1,length(X2))
      X2num<-cbind(X2,indexObservation)
      
      for (i in seq(1,resolution) ) {
        df.ind=rbind.data.frame(df.ind,cbind(vectX1[i],X2num))
      }
      
      names(df.ind)[1]<-"X1"
      head(df.ind)
      
    }
    
    if (dataset.number==2) {
      df2.model<-df
      df2.model$X1X2<-df$X1*df$X2
      
      mylogit <- glm(Y ~ X1X2+X2+X1, data = df2.model, family = "binomial")
      summary(mylogit)
      mylogit.true<-mylogit
      mylogit.true$coefficients<-c(-6,20,10,-10)
      
      pred<-predict(mylogit, newdata = df2.model, type = "response")
      resolution=gridsize
      vectX1<-(seq(as.double(fmin), as.double(fmax),length.out = resolution))
      
      
      df.ind<-data.frame()
      indexObservation<-seq(1,length(X2))
      X2num<-cbind(X2,indexObservation)
      
      for (i in seq(1,resolution) ) {
        df.ind=rbind.data.frame(df.ind,cbind(cbind(vectX1[i],X2num),vectX1[i]*X2num[,1]))
      }
      
      names(df.ind)[1]<-"X1"
      names(df.ind)[4]<-"X1X2"
      head(df.ind)
    }
    
    
    if (dataset.number==3) {
      df3.model<-df
      df3.model$X1carre<-df$X1^2
      
      mylogit <- glm(Y ~ X1carre+X2, data = df3.model, family = "binomial")
      summary(mylogit)
      mylogit.true<-mylogit
      mylogit.true$coefficients<-c(-2,5,0)
      
      pred<-predict(mylogit, newdata = df3.model, type = "response")
      resolution=gridsize
      vectX1<-(seq(as.double(fmin), as.double(fmax), length.out = resolution))
      vect2X1<-data.frame(vectX1,vectX1carre=vectX1^2)
      
      
      df.ind<-data.frame()
      indexObservation<-seq(1,length(X2))
      X2num<-cbind(X2,indexObservation)
      
      for (i in seq(1,resolution) ) {
        df.ind=rbind.data.frame(df.ind,cbind(vect2X1[i,],X2num))
      }
      
      
      names(df.ind)[1]<-"X1"
      names(df.ind)[2]<-"X1carre"
      head(df.ind)
    }
    
    PartialPrediction<-predict(mylogit, newdata = df.ind, type="response")
    PartialPrediction.true<-predict(mylogit.true, newdata = df.ind, type="response")
    
    df.ind$PartialPrediction<-PartialPrediction
    df.ind$PartialPrediction.true<-PartialPrediction.true
    
    # Creates the partial depenande dataframe with the real model
    meansX1=rep(-1, resolution)
    meansX1.true=rep(-1, resolution)
    
    for (i in seq(1,resolution) ) {
      indexi=which(df.ind$X1==vectX1[i])
      meani=mean(df.ind$PartialPrediction[indexi])
      mean.truei=mean(df.ind$PartialPrediction.true[indexi])
      meansX1[i]<-meani
      meansX1.true[i]<-mean.truei
    }
    
    meansX1<-(1-meansX1)
    meansX1.true<-(1-meansX1.true)
    
    partialPredictionDataLogReg=data.frame(X1=vectX1, probaMoy=meansX1, probaMoy.true<-meansX1.true)
    
    pd.plot$probalr.model<-partialPredictionDataLogReg$probaMoy
    pd.plot$Model<-partialPredictionDataLogReg$probaMoy.true
    
    # Donnes difference
    pd.plot.diff<-pd.plot
    pd.plot.diff<-data.frame(pd.plot.diff-cbind(0,replicate(dim(pd.plot.diff)[2]-1,pd.plot$Model)))
    
    
    if (visualize==TRUE) {
      PlotPartialDependance(pd.plot, feature.chosen.name, title = paste("Partial dependance plot for train dataset", dataset.number, "n=",n))
     }
    res = NULL
    res$pdp = PlotPartialDependance(pd.plot, feature.chosen.name, title = paste("Partial dependance plot for train dataset", dataset.number, "n=",n))
    res$dataset = plot.data
    return(res)
  }
  
  
  ## launch ----
  
  # Computation of pdps
  n = 1e3
  res.1 = PdpAnalysis(n, gridsize = 40, feature.chosen.name = "X1", dataset.number = 1, visualize = visualize) 
  res.2 = PdpAnalysis(n, gridsize = 40, feature.chosen.name = "X1", dataset.number = 2, visualize = visualize) 
  res.3 = PdpAnalysis(n, gridsize = 40, feature.chosen.name = "X1", dataset.number = 3, visualize = visualize) 
  
  # Change the color and legends
  police.size = 18
  
  res.1$pdp = res.1$pdp + theme(legend.title=element_blank()) + scale_colour_grey(start = 0,end = 0.7) +
    theme(legend.justification=c(1,1),, text = element_text(size=police.size), legend.position=c(1,1), legend.background = element_rect(colour = "black", size=.5, linetype="dotted"))
  res.2$pdp = res.2$pdp + theme(legend.position="none", text = element_text(size=police.size)) + scale_colour_grey(start = 0,end = 0.7)
  res.3$pdp = res.3$pdp + theme(legend.position="none", text = element_text(size=police.size)) + scale_colour_grey(start = 0,end = 0.7)
  
  res.1$dataset = res.1$dataset + theme(legend.title=element_blank()) +
    theme(legend.justification=c(1,1), text = element_text(size=police.size), legend.position=c(1,1), legend.background = element_rect(colour = "black", size=.5, linetype="dotted"))
  res.2$dataset= res.2$dataset + theme(legend.position="none", text = element_text(size=police.size))
  res.3$dataset = res.3$dataset + theme(legend.position="none", text = element_text(size=police.size))
  
  
  library(cowplot)
  # plot grid
  pdpgrid = plot_grid(res.1$dataset, res.1$pdp,
                      res.2$dataset, res.2$pdp,
                      res.3$dataset, res.3$pdp,
                      #labels=c("A", "B"), 
                      ncol = 2, nrow = 3)
  
  print(pdpgrid)
  
  
  
  jpeg(filename = "Data/Pictures/Figure1_PDP.jpeg", width = 400, height = 450)
  plot(pdpgrid)
  dev.off()
  
  
}


