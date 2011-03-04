
!========================================================================
!
!                   S P E C F E M 2 D  Version 6.1
!                   ------------------------------
!
! Copyright Universite de Pau, CNRS and INRIA, France,
! and Princeton University / California Institute of Technology, USA.
! Contributors: Dimitri Komatitsch, dimitri DOT komatitsch aT univ-pau DOT fr
!               Nicolas Le Goff, nicolas DOT legoff aT univ-pau DOT fr
!               Roland Martin, roland DOT martin aT univ-pau DOT fr
!               Christina Morency, cmorency aT princeton DOT edu
!
! This software is a computer program whose purpose is to solve
! the two-dimensional viscoelastic anisotropic or poroelastic wave equation
! using a spectral-element method (SEM).
!
! This software is governed by the CeCILL license under French law and
! abiding by the rules of distribution of free software. You can use,
! modify and/or redistribute the software under the terms of the CeCILL
! license as circulated by CEA, CNRS and INRIA at the following URL
! "http://www.cecill.info".
!
! As a counterpart to the access to the source code and rights to copy,
! modify and redistribute granted by the license, users are provided only
! with a limited warranty and the software's author, the holder of the
! economic rights, and the successive licensors have only limited
! liability.
!
! In this respect, the user's attention is drawn to the risks associated
! with loading, using, modifying and/or developing or reproducing the
! software by the user in light of its specific status of free software,
! that may mean that it is complicated to manipulate, and that also
! therefore means that it is reserved for developers and experienced
! professionals having in-depth computer knowledge. Users are therefore
! encouraged to load and test the software's suitability as regards their
! requirements in conditions enabling the security of their systems and/or
! data to be ensured and, more generally, to use and operate it in the
! same conditions as regards security.
!
! The full text of the license is available in file "LICENSE".
!
!========================================================================


#ifdef USE_MPI

! subroutines to sort MPI buffers to assemble between chunks

  subroutine sort_array_coordinates(npointot,x,z,ibool,iglob,loc,ifseg, &
                                    nglob,ind,ninseg,iwork,work)

! this routine MUST be in double precision to avoid sensitivity
! to roundoff errors in the coordinates of the points
!
! returns: sorted indexing array (ibool),  reordering array (iglob) & number of global points (nglob)

  implicit none

  include "constants.h"

  integer,intent(in) :: npointot
  integer,intent(out) :: nglob

  integer,intent(inout) :: ibool(npointot)
  
  integer iglob(npointot),loc(npointot)
  integer ind(npointot),ninseg(npointot)
  logical ifseg(npointot)
  double precision,intent(in) :: x(npointot),z(npointot)
  integer iwork(npointot)
  double precision work(npointot)

  ! local parameters
  integer ipoin,i,j
  integer nseg,ioff,iseg,ig
  ! define a tolerance, normalized radius is 1., so let's use a small value
  double precision,parameter :: xtol = SMALLVALTOL

  ! establish initial pointers
  do ipoin=1,npointot
    loc(ipoin)=ipoin
  enddo

  ifseg(:)=.false.

  nseg=1
  ifseg(1)=.true.
  ninseg(1)=npointot

  do j=1,NDIM

    ! sort within each segment
    ioff=1
    do iseg=1,nseg
    
      if(j == 1) then
        call rank_buffers(x(ioff),ind,ninseg(iseg))
      else if(j == 2) then
        call rank_buffers(z(ioff),ind,ninseg(iseg))
      endif

      call swap_all_buffers(ibool(ioff),loc(ioff), &
                  x(ioff),z(ioff),iwork,work,ind,ninseg(iseg))

      ioff=ioff+ninseg(iseg)
    enddo

    ! check for jumps in current coordinate
    if(j == 1) then
      do i=2,npointot
        if(dabs(x(i)-x(i-1)) > xtol) ifseg(i)=.true.
      enddo
    else if(j == 2) then
      do i=2,npointot
        if(dabs(z(i)-z(i-1)) > xtol) ifseg(i)=.true.
      enddo
    endif

    ! count up number of different segments
    nseg=0
    do i=1,npointot
      if(ifseg(i)) then
        nseg=nseg+1
        ninseg(nseg)=1
      else
        ninseg(nseg)=ninseg(nseg)+1
      endif
    enddo
  enddo

  ! assign global node numbers (now sorted lexicographically)
  ig=0
  do i=1,npointot
    if(ifseg(i)) ig=ig+1
    iglob(loc(i))=ig
  enddo

  nglob=ig

  end subroutine sort_array_coordinates

! -------------------- library for sorting routine ------------------

! sorting routines put here in same file to allow for inlining

  subroutine rank_buffers(A,IND,N)
!
! Use Heap Sort (Numerical Recipes)
!
  implicit none

  integer n
  double precision A(n)
  integer IND(n)

  integer i,j,l,ir,indx
  double precision q

  do j=1,n
    IND(j)=j
  enddo

  if(n == 1) return

  L=n/2+1
  ir=n
  100 CONTINUE
   IF(l>1) THEN
      l=l-1
      indx=ind(l)
      q=a(indx)
   ELSE
      indx=ind(ir)
      q=a(indx)
      ind(ir)=ind(1)
      ir=ir-1
      if (ir == 1) then
         ind(1)=indx
         return
      endif
   ENDIF
   i=l
   j=l+l
  200    CONTINUE
   IF(J <= IR) THEN
      IF(J < IR) THEN
         IF(A(IND(j)) < A(IND(j+1))) j=j+1
      ENDIF
      IF (q < A(IND(j))) THEN
         IND(I)=IND(J)
         I=J
         J=J+J
      ELSE
         J=IR+1
      ENDIF
   goto 200
   ENDIF
   IND(I)=INDX
  goto 100
  end subroutine rank_buffers

! -------------------------------------------------------------------

  subroutine swap_all_buffers(IA,IB,A,B,IW,W,ind,n)
!
! swap arrays IA, IB, A and B according to addressing in array IND
!
  implicit none

  integer n

  integer IND(n)
  integer IA(n),IB(n),IW(n)
  double precision A(n),B(n),W(n)

  integer i

  do i=1,n
    W(i)=A(i)
    IW(i)=IA(i)
  enddo

  do i=1,n
    A(i)=W(ind(i))
    IA(i)=IW(ind(i))
  enddo

  do i=1,n
    W(i)=B(i)
    IW(i)=IB(i)
  enddo

  do i=1,n
    B(i)=W(ind(i))
    IB(i)=IW(ind(i))
  enddo

  end subroutine swap_all_buffers

#endif