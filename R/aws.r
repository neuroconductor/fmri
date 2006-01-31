#
#    R - function  aws3D  for vector-valued  Adaptive Weights Smoothing (AWS)
#    in 3D                                    
#
#    emaphazises on the propagation-separation approach 
#
#    Copyright (C) 2005 Weierstrass-Institut fuer
#                       Angewandte Analysis und Stochastik (WIAS)
#
#    Author:  Joerg Polzehl
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
#  USA.
#
#     default parameters:  
#       
#             sagg:          heta=2   qtau=.95     
#             Gaussian:      qlambda=.96          
#
vaws3D <- function(y,qlambda=NULL,qtau=NULL,lkern="Triangle",aggkern="Uniform",
                   sigma2=NULL,hinit=NULL,hincr=NULL,hmax=NULL,lseq=NULL,
                   heta=NULL,u=NULL,graph=FALSE,demo=FALSE,wghts=NULL,
                   spmin=0,spmax=5,scorr=0,vwghts=1) {
  #  Auxilary functions
  IQRdiff <- function(y) IQR(diff(y))/1.908

  #
  updtheta <- function(zobj,tobj,cpar,aggkern) {
    heta <- cpar$heta
    tau1 <- cpar$tau1
    tau2 <- cpar$tau2
    kstar <- cpar$kstar
    hakt <- zobj$hakt
    tau <- 2*(tau1+tau2*max(kstar-log(hakt),0))
    hakt <- zobj$hakt
    bi <- zobj$bi
    bi2 <- zobj$bi2
    thetanew <- zobj$ai/bi 
    theta <- tobj$theta
    thetanew[tobj$fix] <- theta[tobj$fix]
    if (hakt>heta) {
      eta <- switch(aggkern,
                    "Uniform"=as.numeric(zobj$bi0/tau*(thetanew-theta)^2>1),
                    "Triangle"=pmin(1,zobj$bi0/tau*(thetanew-theta)^2),
		    as.numeric(zobj$bi0/tau*(thetanew-theta)^2>1))
    } else {
      eta <- rep(0,length(theta))
    }
    eta[tobj$fix] <- 1
    theta <- (1-eta)*thetanew + eta * theta
    eta <- eta[1:length(bi)]
    bi <- (1-eta)*bi + eta * tobj$bi
    bi2 <- (1-eta)*bi2 + eta * tobj$bi2
    list(theta=theta,bi=bi,bi2=bi2,eta=eta,fix=(eta==1))
  }

  # first check arguments and initialize
  args <- match.call()

  # set cut off point in K_{st}(x) = exp(-x) I_{x<spmax}
  #spmax <- 5

  # test dimension of data (vector of 3D) and define dimension related stuff
  d <- 3
  dy <- dim(y)
  n1 <- dy[1]
  n2 <- dy[2]
  n3 <- dy[3]
  n <- n1*n2*n3
  if (length(dy)==d) {
    dim(y) <- dy <- c(dy,1)
  } else if (length(dy)!=d+1) {
    stop("y has to be 3 or 4 dimensional")
  }
  dv <- dim(y)[d+1]

  # define vwghts
  if (length(vwghts)>dv) vwghts <- vwghts[1:dv]
  dv0 <- length(vwghts)

  # MAE
  mae <- NULL

  # define heta
  if (is.null(heta)) heta <- max(2,hinit+.5)
  heta <- max(heta,2)

  # define qlambda, lambda, qtau, tau1, tau2
  if (is.null(qlambda)) qlambda <- .985
  if (qlambda<.9) warning("Inappropriate value of qlambda")
  if (qlambda>=1) { # thats stagewise aggregation with kernel specified by aggkern
    if (is.null(qtau)) qtau <- .4
    if (qtau==1) tau1 <- 1e50 else tau1 <- qchisq(qtau,1)
    if (aggkern=="Triangle") tau1 <- 2.5*tau1
    tau2 <- tau1/2
  } else {
    if (is.null(qtau)) qtau <- .95
    if (qtau>=1) {
      tau1 <- 1e50 
    } else {
      tau1 <- qchisq(qtau,1)
    }
    if (aggkern=="Triangle") tau1 <- 2.5*tau1
    tau2 <- tau1/2
  }
  if (qlambda<1) {
    vwghts <- vwghts/max(vwghts)
    df <- sum(vwghts^2)^2/sum(vwghts^4)
    lambda <- qchisq(qlambda,df) 
  } else {
    lambda <- 1e50
  }

  # define cpar
  cpar <- list(heta=heta,tau1=tau1,tau2=tau2)
  cpar$kstar <- log(5)

  # set the code for the kernel (used in lkern) and set lambda
  lkern <- switch(lkern,
                  Triangle=2,
                  Quadratic=3,
                  Cubic=4,
                  Uniform=1,
                  Gaussian=5,
                  2)

  # set hinit and hincr if not provided
  if (is.null(hinit)||hinit<1) hinit <- 1

  # define hmax
  if (is.null(hmax)) hmax <- 5    # uses a maximum of about 520 points

  # re-define bandwidth for Gaussian lkern!!!!
  if (lkern==5) {
    # assume  hmax was given in  FWHM  units (Gaussian kernel will be truncated at 4)
    hmax <- hmax*0.42445*4
    hinit <- min(hinit,hmax)
  }

  # define hincr
  if (is.null(hincr)||hincr<=1) hincr <- 1.25
  hincr <- hincr^(1/d)

  # determine corresponding bandwidth for specified correlation
  h0 <- rep(0,length(scorr))
  if (max(scorr)>0) {
    h0 <- numeric(length(scorr))
    for (i in 1:length(h0)) h0[i] <- get.bw.gauss(scorr[i],interv=2)
    if (length(h0)<d) h0 <- rep(h0[1],d)
    cat("Corresponding bandwiths for specified correlation:",h0,"\n")
  }

  # estimate variance in the gaussian case if necessary  
  if (is.null(sigma2)) {
    sigma2 <- IQRdiff(as.vector(y))^2
    if (scorr[1]>0) sigma2<-sigma2*Varcor.gauss(h0)*Spatialvar.gauss(h0*c(1,wghts),1e-5,d)
    cat("Estimated variance: ", signif(sigma2,4),"\n")
  }
  if (length(sigma2)==1) { # homoskedastic Gaussian case
    lambda <- lambda*sigma2*2 
    cpar$tau1 <- cpar$tau1*sigma2*2 
    cpar$tau2 <- cpar$tau2*sigma2*2 
  } else { # heteroskedastic Gaussian case
    if (length(sigma2)!=n) stop("sigma2 does not have length 1 or same length as y")
    lambda <- lambda*2 
    cpar$tau1 <- cpar$tau1*2 
    cpar$tau2 <- cpar$tau2*2 
    sigma2 <- 1/sigma2 #  taking the invers yields simpler formulaes 
  }

  # demo mode should deliver graphics!
  if (demo && !graph) graph <- TRUE
  

  # Initialize  list for theta
  if (is.null(wghts)) wghts <- c(1,1,1)
  hinit <- hinit/wghts[1]
  hmax <- hmax/wghts[1]
  wghts <- (wghts[2:3]/wghts[1])
  tobj <- list(bi= rep(1,n), bi2= rep(1,n), theta= y, fix=rep(FALSE,n))
  zobj <- list(ai=y, bi0= rep(1,n))
  biold <- rep(1,n)
  if (length(sigma2)==n) vred <- rep(1,n)
  steps <- as.integer(log(hmax/hinit)/log(hincr)+1)

  # define lseq
  if (is.null(lseq)) lseq <- c(1.75,1.35,1.2,1.2,1.2,1.2)
  if (length(lseq)<steps) lseq <- c(lseq,rep(1,steps-length(lseq)))
  lseq <- lseq[1:steps]

  k <- 1
  hakt <- hinit
  hakt0 <- hinit
  lambda0 <- lambda
  if (hinit>1) lambda0 <- 1e50 # that removes the stochstic term for the first step

  # run single steps to display intermediate results
  while (hakt<=hmax) {
    dlw <- (2*trunc(hakt/c(1,wghts))+1)[1:d]
    if (scorr[1]>=0.1) lambda0 <- lambda0 * Spatialvar.gauss(hakt0/0.42445/4*c(1,wghts),h0*c(1,wghts),d) /
                                            Spatialvar.gauss(h0*c(1,wghts),1e-5,d) /
                                            Spatialvar.gauss(hakt0/0.42445/4*c(1,wghts),1e-5,d)
    # Correction C(h0,hakt) for spatial correlation depends on h^{(k-1)}  all bandwidth-arguments in FWHM 
    hakt0 <- hakt
    if (length(sigma2)==n) { # heteroskedastic Gaussian case
      zobj <- .Fortran("chaws",as.double(y),
                       as.logical(tobj$fix),
                       as.double(sigma2),
                       as.integer(n1),
                       as.integer(n2),
                       as.integer(n3),
		       as.integer(dv),
		       as.integer(dv0),
                       hakt=as.double(hakt),
                       as.double(lambda0),
                       as.double(tobj$theta),
                       bi=as.double(tobj$bi),
		       bi2=double(n),
                       bi0=as.double(zobj$bi0),
		       vred=double(n),
                       ai=as.double(zobj$ai),
                       as.integer(lkern),
	               as.double(spmin),
		       as.double(spmax),
		       double(prod(dlw)),
		       as.double(wghts),
		       as.double(vwghts),
		       double(dv),#swjy
		       double(dv0),#thi
		       double(dv0),#thj
		       PACKAGE="fmri")[c("bi","bi0","bi2","vred","ai","hakt")]
      vred[!tobj$fix] <- zobj$vred[!tobj$fix]
    } else { # all other cases
      zobj <- .Fortran("caws",as.double(y),
                       as.logical(tobj$fix),
                       as.integer(n1),
                       as.integer(n2),
                       as.integer(n3),
		       as.integer(dv),
		       as.integer(dv0),
                       hakt=as.double(hakt),
                       as.double(lambda0),
                       as.double(tobj$theta),
                       bi=as.double(tobj$bi),
		       bi2=double(n),
                       bi0=as.double(zobj$bi0),
                       ai=as.double(zobj$ai),
                       as.integer(lkern),
                       as.double(spmin),
		       as.double(spmax),
		       double(prod(dlw)),
		       as.double(wghts),
		       as.double(vwghts),
		       double(dv),#swjy
		       double(dv0),#thi
		       double(dv0),#thj
		       PACKAGE="fmri")[c("bi","bi0","bi2","ai","hakt")]
    }
    gc()
    dim(zobj$ai) <- dy
    if (hakt>n1/2) zobj$bi0 <- hincr^d*biold
    biold <- zobj$bi0
    tobj <- updtheta(zobj,tobj,cpar,aggkern)
    gc()
    dim(tobj$theta) <- dy
    dim(tobj$bi) <- dy[-4]
    dim(tobj$eta) <- dy[-4]
    if (graph) {
      par(mfrow=c(2,2),mar=c(1,1,3,.25),mgp=c(2,1,0))
      image(y[,,n3%/%2+1,1],col=gray((0:255)/255),xaxt="n",yaxt="n")
      title(paste("Observed Image  min=",signif(min(y),3)," max=",signif(max(y),3)))
      image(tobj$theta[,,n3%/%2+1,1],col=gray((0:255)/255),xaxt="n",yaxt="n")
      title(paste("Reconstruction  h=",signif(hakt,3)," min=",signif(min(tobj$theta),3)," max=",signif(max(tobj$theta),3)))
      image(tobj$bi[,,n3%/%2+1],col=gray((0:255)/255),xaxt="n",yaxt="n")
      title(paste("Sum of weights: min=",signif(min(tobj$bi),3)," mean=",signif(mean(tobj$bi),3)," max=",signif(max(tobj$bi),3)))
      image(tobj$eta[,,n3%/%2+1],col=gray((0:255)/255),xaxt="n",yaxt="n",zlim=c(0,1))
      title("eta")
    }
    if (!is.null(u)) {
      cat("bandwidth: ",signif(hakt,3),"eta==1",sum(tobj$eta==1),"   MSE: ",
          signif(mean((tobj$theta-u)^2),3),"   MAE: ",signif(mean(abs(tobj$theta-u)),3)," mean(bi)=",signif(mean(tobj$bi),3),"\n")
      mae <- c(mae,signif(mean(abs(tobj$theta-u)),3))
    }
    if (demo) readline("Press return")
    hakt <- hakt*hincr
    x <- 1.25^(k-1)
    scorrfactor <- x/(3^d*prod(scorr)*prod(h0)+x)
    lambda0 <- lambda*lseq[k]*scorrfactor
    k <- k+1
    gc()
  }
###                                                                       
###            end cases                                                  
###                                 
###   component var contains an estimate of Var(tobj$theta) if aggkern="Uniform", or if qtau1=1 
###   
  if (length(sigma2)==n) {
# heteroskedastic Gaussian case 
    vartheta <- tobj$bi2/tobj$bi^2 
  } else {
    vartheta <- sigma2*tobj$bi2/tobj$bi^2 
    vred<-tobj$bi2/tobj$bi^2
  }
  hakt <- hakt/hincr
  cgh <- Spatialvar.gauss(hakt/0.42445/4*c(1,wghts),h0*c(1,wghts)+1e-5,d)/Spatialvar.gauss(hakt/0.42445/4*c(1,wghts),1e-5,d) / Spatialvar.gauss(h0*c(1,wghts),1e-5,d) 
  vartheta <- vartheta*cgh 
#vred<-vred/Spatialvar.gauss(hakt/0.42445/4*c(1,wghts),h0*c(1,wghts)+1e-5,d)*Spatialvar.gauss(hakt/0.42445/4*c(1,wghts),1e-5,d)
# 
#   this accounts for intrinsic correlation (data), less variance reduction (larger variance, larger variance reduction factor) if data were correlated
#
  z <- list(theta=tobj$theta,ni=tobj$bi,qi=tobj$bi2,cgh=cgh,var=vartheta,vred=vred,y=y,
            hmax=hakt,mae=mae,lseq=c(0,lseq[-steps]),call=args)
  class(z) <- "aws.gaussian"
  z
}
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#
#   reduced version for qtau==1, heteroskedastic variances only, exact value for Variance reduction
#
#################################################################################################################################################
#################################################################################################################################################
#
#    R - function  aws3D  for vector-valued  Adaptive Weights Smoothing (AWS)
#    in 3D                                    
#
#    emaphazises on the propagation-separation approach 
#
#    Copyright (C) 2005 Weierstrass-Institut fuer
#                       Angewandte Analysis und Stochastik (WIAS)
#
#    Author:  Joerg Polzehl
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
#  USA.
#
#     default parameters:  
#       
#             sagg:          heta=2   qtau=.95     
#             Gaussian:      qlambda=.96          
#
vaws3D2 <- function(y,qlambda=NULL,qtau=NULL,lkern="Triangle",aggkern="Uniform",
                   sigma2=NULL,hinit=NULL,hincr=NULL,hmax=NULL,lseq=NULL,
                   heta=NULL,u=NULL,graph=FALSE,demo=FALSE,wghts=NULL,
                   spmin=0,spmax=5,scorr=0,vwghts=1) {
  #  Auxilary functions
  IQRdiff <- function(y) IQR(diff(y))/1.908

  #
  # first check arguments and initialize
  #
  args <- match.call()

  # set cut off point in K_{st}(x) = exp(-x) I_{x<spmax}
  #spmax <- 5

  # test dimension of data (vector of 3D) and define dimension related stuff
  d <- 3
  dy <- dim(y)
  n1 <- dy[1]
  n2 <- dy[2]
  n3 <- dy[3]
  n <- n1*n2*n3
  if (length(dy)==d) {
    dim(y) <- dy <- c(dy,1)
  } else if (length(dy)!=d+1) {
    stop("y has to be 3 or 4 dimensional")
  }
  dv <- dim(y)[d+1]

  # define vwghts
  if (length(vwghts)>dv) vwghts <- vwghts[1:dv]
  dv0 <- length(vwghts)

  # MAE
  mae <- NULL


  # define qlambda, lambda
  if (is.null(qlambda)) qlambda <- .985
  if (qlambda<.9) warning("Inappropriate value of qlambda")
  if (qlambda<1) {
    vwghts <- vwghts/max(vwghts)
    df <- sum(vwghts^2)^2/sum(vwghts^4)
    lambda <- qchisq(qlambda,df) 
  } else {
    lambda <- 1e50
  }

  # set the code for the kernel (used in lkern) and set lambda
  lkern <- switch(lkern,
                  Triangle=2,
                  Quadratic=3,
                  Cubic=4,
                  Uniform=1,
                  Gaussian=5,
                  2)

  # set hinit and hincr if not provided
  if (is.null(hinit)||hinit<1) hinit <- 1

  # define hmax
  if (is.null(hmax)) hmax <- 5    # uses a maximum of about 520 points

  # re-define bandwidth for Gaussian lkern!!!!
  if (lkern==5) {
    # assume  hmax was given in  FWHM  units (Gaussian kernel will be truncated at 4)
    hmax <- hmax*0.42445*4
    hinit <- min(hinit,hmax)
  }

  # define hincr
  if (is.null(hincr)||hincr<=1) hincr <- 1.25
  hincr <- hincr^(1/d)

  # determine corresponding bandwidth for specified correlation
  h0 <- rep(0,length(scorr))
  if (max(scorr)>0) {
    h0 <- numeric(length(scorr))
    for (i in 1:length(h0)) h0[i] <- get.bw.gauss(scorr[i],interv=2)
    if (length(h0)<d) h0 <- rep(h0[1],d)
    cat("Corresponding bandwiths for specified correlation:",h0,"\n")
  }

  # estimate variance in the gaussian case if necessary  
  if (is.null(sigma2)) {
    sigma2 <- IQRdiff(as.vector(y))^2
    if (scorr[1]>0) sigma2<-sigma2*Varcor.gauss(h0)*Spatialvar.gauss(h0*c(1,wghts),1e-5,d)
    cat("Estimated variance: ", signif(sigma2,4),"\n")
  }
  if (length(sigma2)==1) sigma2<-array(sigma2,dy[1:3]) 
  # deal with homoskedastic Gaussian case by extending sigma2
  if (length(sigma2)!=n) stop("sigma2 does not have length 1 or same length as y")
    lambda <- lambda*2 
    sigma2 <- 1/sigma2 #  taking the invers yields simpler formulaes 

  # demo mode should deliver graphics!
  if (demo && !graph) graph <- TRUE
  

  # Initialize  list for ai, bi and theta
  if (is.null(wghts)) wghts <- c(1,1,1)
  hinit <- hinit/wghts[1]
  hmax <- hmax/wghts[1]
  wghts <- (wghts[2:3]/wghts[1])
  tobj <- list(ai=y, bi= rep(1,n))
  theta <- y
  steps <- as.integer(log(hmax/hinit)/log(hincr)+1)

  # define lseq
  if (is.null(lseq)) lseq <- c(1.75,1.35,1.2,1.2,1.2,1.2)
  if (length(lseq)<steps) lseq <- c(lseq,rep(1,steps-length(lseq)))
  lseq <- lseq[1:steps]

  k <- 1
  hakt <- hinit
  hakt0 <- hinit
  lambda0 <- lambda
  if (hinit>1) lambda0 <- 1e50 # that removes the stochstic term for the first step

  # run single steps to display intermediate results
  while (hakt<=hmax) {
    dlw <- (2*trunc(hakt/c(1,wghts))+1)[1:d]
    if (scorr[1]>=0.1) lambda0 <- lambda0 * Spatialvar.gauss(hakt0/0.42445/4*c(1,wghts),h0*c(1,wghts),d) /
                                            Spatialvar.gauss(h0*c(1,wghts),1e-5,d) /
                                            Spatialvar.gauss(hakt0/0.42445/4*c(1,wghts),1e-5,d)
    # Correction C(h0,hakt) for spatial correlation depends on h^{(k-1)}  all bandwidth-arguments in FWHM 
    hakt0 <- hakt
    theta0 <- theta
    bi0 <- tobj$bi
#
#   need these values to compute variances after the last iteration
#
      tobj <- .Fortran("chaws2",as.double(y),
                       as.double(sigma2),
                       as.integer(n1),
                       as.integer(n2),
                       as.integer(n3),
		       as.integer(dv),
		       as.integer(dv0),
                       hakt=as.double(hakt),
                       as.double(lambda0),
                       as.double(theta0),
                       bi=as.double(bi0),
                       ai=as.double(tobj$ai),
                       as.integer(lkern),
	               as.double(spmin),
		       as.double(spmax),
		       double(prod(dlw)),
		       as.double(wghts),
		       as.double(vwghts),
		       double(dv),#swjy
		       double(dv0),#thi
		       double(dv0),#thj
		       PACKAGE="fmri")[c("bi","ai","hakt")]
    gc()
    dim(tobj$ai) <- dy
    gc()
    theta <- array(tobj$ai/tobj$bi,dy) 
    dim(tobj$bi) <- dy[-4]
    if (graph) {
      par(mfrow=c(1,3),mar=c(1,1,3,.25),mgp=c(2,1,0))
      image(y[,,n3%/%2+1,1],col=gray((0:255)/255),xaxt="n",yaxt="n")
      title(paste("Observed Image  min=",signif(min(y),3)," max=",signif(max(y),3)))
      image(theta[,,n3%/%2+1,1],col=gray((0:255)/255),xaxt="n",yaxt="n")
      title(paste("Reconstruction  h=",signif(hakt,3)," min=",signif(min(tobj$theta),3)," max=",signif(max(tobj$theta),3)))
      image(tobj$bi[,,n3%/%2+1],col=gray((0:255)/255),xaxt="n",yaxt="n")
      title(paste("Sum of weights: min=",signif(min(tobj$bi),3)," mean=",signif(mean(tobj$bi),3)," max=",signif(max(tobj$bi),3)))
    }
    if (!is.null(u)) {
      cat("bandwidth: ",signif(hakt,3),"eta==1",sum(tobj$eta==1),"   MSE: ",
          signif(mean((theta-u)^2),3),"   MAE: ",signif(mean(abs(theta-u)),3)," mean(bi)=",signif(mean(tobj$bi),3),"\n")
      mae <- c(mae,signif(mean(abs(theta-u)),3))
    }
    if (demo) readline("Press return")
    hakt <- hakt*hincr
    x <- 1.25^(k-1)
    scorrfactor <- x/(3^d*prod(scorr)*prod(h0)+x)
    lambda0 <- lambda*lseq[k]*scorrfactor
    k <- k+1
    gc()
  }
###                                                                       
###   Now compute variance of theta and variance reduction factor (with respect to the spatially uncorrelated situation
###   
      g <- trunc(h0/c(1,wghts)/2.3548*4)
#
#  use g <- trunc(h0/c(1,wghts)/2.3548*3)+1 if it takes to long
#
      if(h0[1]>0) gw1 <- dnorm(-(g[1]):g[1],0,h0[1]/2.3548)/dnorm(0,0,h0[1]/2.3548) else gw1 <- 1
      if(h0[2]>0) gw2 <- dnorm(-(g[2]):g[2],0,h0[2]/2.3548/wghts[1])/dnorm(0,0,h0[2]/2.3548/wghts[1]) else gw2 <- 1
      if(h0[3]>0) gw3 <- dnorm(-(g[3]):g[3],0,h0[3]/2.3548/wghts[2])/dnorm(0,0,h0[3]/2.3548/wghts[2]) else gw3 <- 1
      gwght <- outer(gw1,outer(gw2,gw3,"*"),"*")
      gwght <- gwght/sum(gwght)
      dgw <- dim(gwght)
      vred <- .Fortran("chawsvr",as.double(y),
                       as.double(sigma2),
                       as.integer(n1),
                       as.integer(n2),
                       as.integer(n3),
		       as.integer(dv),
		       as.integer(dv0),
                       as.double(tobj$hakt),
                       as.double(lambda0),
                       as.double(theta0),# thats the theta needed for the weights
                       as.double(bi0), # thats the bi needed for the weights
		       vred=double(n),
                       as.integer(lkern),
	               as.double(spmin),
		       as.double(spmax),
		       double(prod(dlw)),# lwghts
		       as.double(gwght),# gwghts
		       double(n), # to keep the wij
		       as.integer(dgw),
		       as.double(wghts),
		       as.double(vwghts),
		       double(dv0),#thi
		       double(dv0),#thj
		       PACKAGE="fmri")$vred
      dim(vred) <- dim(sigma2)
      nqg <- .Fortran("nqg",as.double(gwght),
                       as.double(gwght^2),
                       as.integer(dgw[1]),
                       as.integer(dgw[2]),
                       as.integer(dgw[3]),
                       as.integer(n1),
                       as.integer(n2),
                       as.integer(n3),
                       qg=double(n),
		       ng=double(n),
		       PACKAGE="fmri")[c("qg","ng")]
      qg <- array(nqg$qg,dim(sigma2))
      ng <- array(nqg$ng,dim(sigma2))
  vr<-vred
  dim(tobj$bi)<-dim(vred)
  vartheta <- vred/tobj$bi^2/qg
  vred <- vartheta*sigma2/ng^2*qg
# 
#   vred accounts for variance reduction with respect to uncorrelated (\check{sigma}^2) data
#
  z <- list(theta=theta,ni=tobj$bi,var=vartheta,vred=vred,y=y,
            hmax=tobj$hakt,mae=mae,lseq=c(0,lseq[-steps]),call=args,ng=ng,qg=qg,vr=vr,gw=gwght)
  class(z) <- "aws.gaussian"
  z
}
