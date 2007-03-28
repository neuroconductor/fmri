      subroutine corr(res,mask,n1,n2,n3,nv,scorr)

      implicit logical(a-z)
      integer n1,n2,n3,nv
      real*8 scorr(3),res(n1,n2,n3,nv)
      logical mask(n1,n2,n3)
      real*8 z,z2,resi,resip1,vrm,zk,zcorr
      integer i1,i2,i3,i4,k
      
      scorr(1)=0.d0
      scorr(2)=0.d0
      scorr(3)=0.d0
C  correlation in x
      z=0.d0
      z2=0.d0
      zcorr=0.d0
      k=0
      do i1=1,n1-1
         do i2=1,n2
            do i3=1,n3
               if (.not.(mask(i1,i2,i3).and.mask(i1+1,i2,i3))) CYCLE
               do i4=1,nv
                  resi=res(i1,i2,i3,i4)
                  resip1=res(i1+1,i2,i3,i4)
                  if (resi.eq.0.d0.or.resip1.eq.0.d0) CYCLE
                  z=z+resi
                  z2=z2+resi*resi
                  zcorr=zcorr+resi*resip1
                  k=k+1
               enddo
            enddo
         enddo
      enddo
      if (k.gt.0) THEN
         zk=k
         z=z/zk
         vrm=(z2-zk*(z*z))/(zk-1.d0)
         scorr(1)=zcorr/zk/vrm
      ELSE
         scorr(1)=0.d0
         call dblepr("All zero residuals x",20,scorr(1),1)
      END IF
      if(scorr(1).gt.1.d0-1.d-8) THEN
         call dblepr("scorr(1) was",12,scorr(1),1)
         scorr(1) = 1.d0-1.d-8
         call dblepr("scorr(1) reset to",17,scorr(1),1)
      ELSE IF (scorr(1).lt.-1.d0+1.d-8) THEN
         call dblepr("scorr(1) was",12,scorr(1),1)
         scorr(1) = 1.d0-1.d-8
         call dblepr("scorr(1) reset to",17,scorr(1),1)
      END IF
C  correlation in y
      z=0.d0
      z2=0.d0
      zcorr=0.d0
      k=0
      do i1=1,n1
         do i2=1,n2-1
            do i3=1,n3
               if (.not.(mask(i1,i2,i3).and.mask(i1,i2+1,i3))) CYCLE
               do i4=1,nv
                  resi=res(i1,i2,i3,i4)
                  resip1=res(i1,i2+1,i3,i4)
                  if (resi.eq.0.d0.or.resip1.eq.0.d0) CYCLE
                  z=z+resi
                  z2=z2+resi*resi
                  zcorr=zcorr+resi*resip1
                  k=k+1
               enddo
            enddo
         enddo
      enddo
      if (k.gt.0) THEN
         zk=k
         z=z/zk
         vrm=(z2-zk*(z*z))/(zk-1.d0)
         scorr(2)=zcorr/zk/vrm
      ELSE
         scorr(2)=0.d0
         call dblepr("All zero residuals y",20,scorr(2),1)
      END IF
      if(scorr(2).gt.1.d0-1.d-8) THEN
         call dblepr("scorr(2) was",12,scorr(2),1)
         scorr(2) = 1.d0-1.d-8
         call dblepr("scorr(2) reset to",17,scorr(2),1)
      ELSE IF (scorr(2).lt.-1.d0+1.d-8) THEN
         call dblepr("scorr(2) was",12,scorr(2),1)
         scorr(1) = 1.d0-1.d-8
         call dblepr("scorr(2) reset to",17,scorr(2),1)
      END IF
C  correlation in z
      z=0.d0
      z2=0.d0
      zcorr=0.d0
      k=0
      do i1=1,n1
         do i2=1,n2
            do i3=1,n3-1
               if (.not.(mask(i1,i2,i3).and.mask(i1,i2,i3+1))) CYCLE
               do i4=1,nv
                  resi=res(i1,i2,i3,i4)
                  resip1=res(i1,i2,i3+1,i4)
                  if (resi.eq.0.d0.or.resip1.eq.0.d0) CYCLE
                  z=z+resi
                  z2=z2+resi*resi
                  zcorr=zcorr+resi*resip1
                  k=k+1
               enddo
            enddo
         enddo
      enddo
      if (k.gt.0) THEN
         zk=k
         z=z/zk
         vrm=(z2-zk*(z*z))/(zk-1.d0)
         scorr(3)=zcorr/zk/vrm
      ELSE
         scorr(3)=0.d0
         call dblepr("All zero residuals x",20,scorr(3),1)
      END IF
      if(scorr(3).gt.1.d0-1.d-8) THEN
         call dblepr("scorr(3) was",12,scorr(3),1)
         scorr(3) = 1.d0-1.d-8
         call dblepr("scorr(3) reset to",17,scorr(3),1)
      ELSE IF (scorr(3).lt.-1.d0+1.d-8) THEN
         call dblepr("scorr(3) was",12,scorr(3),1)
         scorr(3) = 1.d0-1.d-8
         call dblepr("scorr(3) reset to",17,scorr(3),1)
      END IF
      return
      end