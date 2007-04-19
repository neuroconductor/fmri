fwhm2bw <- function(hfwhm) hfwhm/sqrt(8*log(2))
bw2fwhm <- function(h) h*sqrt(8*log(2))

Varcor.gauss<-function(h,interv = 1){
#
#   Calculates a correction for the variance estimate obtained by (IQRdiff(y)/1.908)^2
#
#   in case of colored noise that was produced by smoothing with lkern and bandwidth h
#
#  interv allows for further discretization of the Gaussian Kernel, result depends on
#  interv for small bandwidths. interv=1  is correct for kernel smoothing, 
#  interv>>1 should be used to handle intrinsic correlation (smoothing preceeding 
#  discretisation into voxel) 
#
#  h in FWHM
#
  h<-fwhm2bw(h)*interv
  ih<-trunc(4*h)+1
  dx<-2*ih+1
  d<-length(h)
  penl <- dnorm(((-ih[1]):ih[1])/h[1])
  if(d==2) penl <- outer(penl,dnorm(((-ih[2]):ih[2])/h[2]),"*")
  if(d==3) penl <- outer(penl,outer(dnorm(((-ih[2]):ih[2])/h[2]),dnorm(((-ih[3]):ih[3])/h[3]),"*"),"*")
  2*sum(penl)^2/sum(diff(penl,interv)^2)/interv^(d)
}

Spatialvar.gauss<-function(h,h0,d,interv=1){
#
#   Calculates the factor of variance reduction obtained for Gaussian Kernel and bandwidth h in 
#
#   case of colored noise that was produced by smoothing with Gaussian kernel and bandwidth h0
#
#   Spatialvar.gauss(lkern,h,h0,d)/Spatialvar.gauss(lkern,h,1e-5,d) gives the 
#   a factor for lambda to be used with bandwidth h 
#
#
#  interv allows for further discretization of the Gaussian Kernel, result depends on
#  interv for small bandwidths. interv=1  is correct for kernel smoothing, 
#  interv>>1 should be used to handle intrinsic correlation (smoothing preceeding 
#  discretisation into voxel) 
#
#  h and h0 in FWHM
#
  h0 <- pmax(h0,1e-5)
  h <- pmax(h,1e-5)
  h<-fwhm2bw(h)*interv
  if(length(h)==1) h<-rep(h,d)
  ih<-trunc(4*h)
  ih<-pmax(1,ih)
  dx<-2*ih+1
  penl<-dnorm(((-ih[1]):ih[1])/h[1])
  if(d==2) penl<-outer(dnorm(((-ih[1]):ih[1])/h[1]),dnorm(((-ih[2]):ih[2])/h[2]),"*")
  if(d==3) penl<-outer(dnorm(((-ih[1]):ih[1])/h[1]),outer(dnorm(((-ih[2]):ih[2])/h[2]),dnorm(((-ih[3]):ih[3])/h[3]),"*"),"*")
  dim(penl)<-dx
  h0<-fwhm2bw(h0)*interv
  if(length(h0)==1) h0<-rep(h0,d)
  ih<-trunc(4*h0)
  ih<-pmax(1,ih)
  dx0<-2*ih+1
  x<- ((-ih[1]):ih[1])/h0[1]
  penl0<-dnorm(((-ih[1]):ih[1])/h0[1])
  if(d==2) penl0<-outer(dnorm(((-ih[1]):ih[1])/h0[1]),dnorm(((-ih[2]):ih[2])/h0[2]),"*")
  if(d==3) penl0<-outer(dnorm(((-ih[1]):ih[1])/h0[1]),outer(dnorm(((-ih[2]):ih[2])/h0[2]),dnorm(((-ih[3]):ih[3])/h0[3]),"*"),"*")
  dim(penl0)<-dx0
  penl0<-penl0/sum(penl0)
  dz<-dx+dx0-1
  z<-array(0,dz)
  if(d==1){
    for(i1 in 1:dx0) {
      ind1<-c(0:(i1-1),(dz-dx0+i1):dz+1)
      ind1<-ind1[ind1<=dz][-1]
      z[-ind1]<-z[-ind1]+penl*penl0[i1]
    }
  } else if(d==2){
    for(i1 in 1:dx0[1]) for(i2 in 1:dx0[2]){
      ind1<-c(0:(i1-1),(dz[1]-dx0[1]+i1):dz[1]+1)
      ind1<-ind1[ind1<=dz[1]][-1]
      ind2<-c(0:(i2-1),(dz[2]-dx0[2]+i2):dz[2]+1)
      ind2<-ind2[ind2<=dz[2]][-1]
      z[-ind1,-ind2]<-z[-ind1,-ind2]+penl*penl0[i1,i2]
    }
  } else if(d==3){
    for(i1 in 1:dx0[1]) for(i2 in 1:dx0[2]) for(i3 in 1:dx0[3]){
      ind1<-c(0:(i1-1),(dz[1]-dx0[1]+i1):dz[1]+1)
      ind1<-ind1[ind1<=dz[1]][-1]
      ind2<-c(0:(i2-1),(dz[2]-dx0[2]+i2):dz[2]+1)
      ind2<-ind2[ind2<=dz[2]][-1]
      ind3<-c(0:(i3-1),(dz[3]-dx0[3]+i3):dz[3]+1)
      ind3<-ind3[ind3<=dz[3]][-1]
      z[-ind1,-ind2,-ind3]<-z[-ind1,-ind2,-ind3]+penl*penl0[i1,i2,i3]
    }
  }
  sum(z^2)/sum(z)^2*interv^d
}

get3Dh.gauss <- function(vred,vwghts,step=1.002,interv=1){
#
#  interv allows for further discretization of the Gaussian Kernel, result depends on
#  interv for small bandwidths. interv=1  is correct for kernel smoothing, 
#  interv>>1 should be used to handle intrinsic correlation (smoothing preceeding 
#  discretisation into voxel) 
#
  n <- length(vred)
  hv <- matrix(0,3,n)
  fixed <- rep(FALSE,n)
  i <- 1
  while (any(!fixed) && i < dim(hvred)[1]) {
    ind<-(1:n)[!fixed][vred[!fixed] >= hvred[i,2]]
    hv[,ind] <- hvred[i,1]
    fixed[ind] <- TRUE
    i <- i + 1
  }
  hv[,!fixed] <- hvred[i,1]
  
  invisible(t(hv))
}

gkernsm <- function(y,h=1) {
#
# h in SD
#
  grid <- function(d) {
    d0 <- d%/%2+1
    gd <- seq(0,1,length=d0)
    if (2*d0==d+1) gd <- c(gd,-gd[d0:2]) else gd <- c(gd,-gd[(d0-1):2])
    gd
  }
  dy <- dim(y)
  if (is.null(dy)) dy<-length(y)
  ldy <- length(dy)
  if (length(h)!=ldy) h <- rep(h[1],ldy)
  kern <- switch(ldy,dnorm(grid(dy),0,2*h/dy),
                 outer(dnorm(grid(dy[1]),0,2*h[1]/dy[1]),
                       dnorm(grid(dy[2]),0,2*h[2]/dy[2]),"*"),
                 outer(outer(dnorm(grid(dy[1]),0,2*h[1]/dy[1]),
                             dnorm(grid(dy[2]),0,2*h[2]/dy[2]),"*"),
                       dnorm(grid(dy[3]),0,2*h[3]/dy[3]),"*"))
  kern <- kern/sum(kern)
  kernsq <- sum(kern^2)
  list(gkernsm=convolve(y,kern,conj=TRUE),kernsq=kernsq)
}

get.bw.gauss <- function(corr, step = 1.001,interv=2) {
  #  get the corresponding FWHM bandwidth for lkern and a given correlation
  #  keep it simple result does not depend on d

  #  interv allows for further discretization of the Gaussian Kernel, result depends on
  #  interv for small bandwidths. interv=1  is correct for kernel smoothing, 
  #  interv>>1 should be used to handle intrinsic correlation (smoothing preceeding 
  #  discretisation into voxel)   
  if (corr < 0.1) {
    h <- 0
  } else { 
    h <- .5
    z <- 0
    while (z<corr) {
      h <- h*step
      z <- get.corr.gauss(h,interv)
    }
    h <- h/step
  }
  h
}

get.corr.gauss <- function(h,interv=1) {
    #
    #   Calculates the correlation of 
    #   colored noise that was produced by smoothing with "gaussian" kernel and bandwidth h
    #   Result does not depend on d for "Gaussian" kernel !!
    #
    #   h in FWHM
    #
    h <- fwhm2bw(h)*interv
    ih <- trunc(4*h+ 2*interv-1)
    dx <- 2*ih+1
    penl <- dnorm(((-ih):ih)/h)
    sum(penl[-(1:interv)]*penl[-((dx-interv+1):dx)])/sum(penl^2)
}

correlation <- function(res,mask = array(1,dim=dim(res)[1:3])) {
  meanpos <- function(a) mean(a[a!=0])
  varpos <- function(a) var(a[a!=0])

  dr <- dim(res)
  if (length(dim(mask)) == 3) {
    if (sum(dim(mask)[1:3] != dr[1:3]) == 0) {
      mask <- rep(mask,dr[4])
      dim(mask) <- dr
      if (any(res*mask!=0)) {
        vrm <- varpos(res*mask)
        x <- meanpos(res[-1,,,]*res[-dr[1],,,]*mask[-1,,,])/vrm
        y <- meanpos(res[,-1,,]*res[,-dr[2],,]*mask[,-1,,])/vrm
        z <- meanpos(res[,,-1,]*res[,,-dr[3],]*mask[,,-1,])/vrm
        c(x,y,z)
      } else {
        warning("Warning: did not found any non-zero residual in mask. Correlation probably wrong!")
        c(0,0,0)
      }
    } else {
      warning("Error: dimension of mask and residui matrices do not match\n")    
    }
  } else {
    warning("Error: can only handle 3 dimensional arrays\n")    
  }    
}

corrrisk <- function(bw,lag,data){
mean((data-thcorr3D(bw,lag))^2)
}

thcorr3D <- function(bw,lag=rep(5,3),wghts=c(1,1,1)){
  g <- trunc(fwhm2bw(bw/wghts)*4)
  gw1 <- dnorm(-(g[1]):g[1],0,fwhm2bw(bw[1])) 
  gw2 <- dnorm(-(g[2]):g[2],0,fwhm2bw(bw[2])/wghts[1])
  gw3 <- dnorm(-(g[3]):g[3],0,fwhm2bw(bw[3])/wghts[2])
  gwght <- outer(gw1,outer(gw2,gw3,"*"),"*")
  gwght <- gwght/sum(gwght)
  dgw <- dim(gwght)
  scorr <- .Fortran("thcorr",as.double(gwght),
                    as.integer(dgw[1]),
                    as.integer(dgw[2]),
                    as.integer(dgw[3]),
                    scorr=double(prod(lag)),
                    as.integer(lag[1]),
                    as.integer(lag[2]),
                    as.integer(lag[3]),
                    PACKAGE="fmri",DUP=TRUE)$scorr
dim(scorr) <- lag
scorr
}
