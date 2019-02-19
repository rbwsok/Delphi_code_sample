���������� ������ (rbwsok@gmail.com)

�������� � ������������ � Delphi 10.1.2 Berlin � 32-� ������ ������ ��� Windows 10 x64.

������ - ����c���� ������ ����� shared memory ������������� �������. ����������� ������������� ��������
���������� ������. ��������� � ���������� �����. 


��������.

������ �������� � ����������:
1. ������������� ������� � shared memory �� ������� ������ ������� � ��������� ��������
2. �������� ������ ����� �������� � ��������
3. ��������� ������ ������ shared memory


1. ������������� ������� � shared memory �� ������� ������ ������� � ��������� ��������

��� ������������� ����� ������� ���������� ���������� � ������� ����������� ��������.

���������� ������ ������ ��� ������ ������� ��� "�������" ���� �������� ��������.

��� ����� �������� - ��� GUID. ��-�� �������� ��������� � �������.

����������/����������� ����� ������� � �������������� �����������/���������� ����� 
������� �������� ��������������� ����� ������ (stream). ����� ������� ����� ���� ��������� 
��� � ����� ������� (����� ��������), ��� � � ������ �����������. ��� ���, � �������, ��� ������� -
���� �� �������� ������ ������� (���� exe ����) � 10-� �������� ������ ��� 
10 �������� (10 exe ������) �� ������ ������ � ������.
��� ������� ������ ������ (stream) ��������� ���� ����� ������������ ������� (thread).

����� ��������� �������� ����������� ����� �������, ������ ��������� ���������� ��� (GUID) ��� ������� �������.
"�������" GUID'�� ����� ����������� �� �������������.

Shared memory ����� ��������� �����������:
- � ������ ������������� ������� ��� "�������" ���� ��������. (� ����� ����������)
- ����� ��� ���� ������, ���������� �� ������ ����� ������. ���������� ������� �������������� ������ ������ � ���� �������.
� ���� ������� ���������� � �������� ������ ������� � �������� (� ��������). ������� ������� � �������� ������ �� 
������� ������� � �������.
- ����� ������ ��������������� ��� �������� ������ (������) - ������ � �������� �����������. �� ������� ������� � �������.

2. �������� ������ ����� �������� � ��������

���� �������� ������ ������� �� ���� ������� � �������������� �������� � ��������� �����.

���� �� ���������� ������ ����������� ������, ����������� ������, ��������� �������� ���������
(��� ������� ��������� ������) � ��������� ������. �������, �������������� �������� � �������� ��
������ ������������ �� ���� �������. ����� ���� ������������ ������� ����� ������ ������������
���� �� ���������.

D � ������ ������ ����������� ������� ��� �������� ����� � ping-pong.

3. ��������� ������ ������ shared memory

��� ���� ������� - ��������� ��������� ����� ������ ��������� - �������� � ��������. ������ ������� � ������� ������
��������� ���� �����. ��� �������� ������, �� �����������, ����� ������� � ���������� ������ ����� ������������
����������� "�����" � ���������� ������.




�������� � ������� ���������

1. ��������� ������ "����������" � ������� "� ���". 

2. ������������ ������� �������������� ��� ���� ������ - ���� �����. ��� ���������� ������� ������������� ���������
������� �� ������������ ���������� � �.�. �������� �������������� "������ ����������" (Completion Port) ������������ �������.

3. ������������ �����-������ (������-������). �������� "������� ����������" ��� "���������� ������-�������". 

4. ������������� ������� �� ������ ������� (� ���������). ������ �������� � ������� ���������� ����� ������������ ���������
��������. � ������� ������������� ��� ���������� (Lock Free).

5. Unit ����� ��������� ������ ���������.


���������������� ���� � ������ ������� � ��������

���������������� ���� ������������ ����� xml ���� ��������� ���������:

<?xml version="1.0" encoding="utf-8" standalone="yes" ?> 
<streams>
  <server outputpath="c:\dst\" /> 
  <stream id="1" file="d:\Music\������� - ����\׸���� �������\�������\2017 - ��������\01. �����.mp3" /> 
  <stream id="2" file="d:\Music\������� - ����\׸���� �������\�������\2017 - ��������\02. �������.mp3" /> 
 ...
</streams>

���� ��� ������� � �������� ������. ��� - options.xml

��� �������:
  <server outputpath="c:\dst\" /> - ���� � �����, ���� ����� ����������� �����. �� ��������� - ����� � exe ������ �������

��� ��������:
  <stream id="1" file="d:\Music\������� - ����\׸���� �������\�������\2017 - ��������\01. �����.mp3" /> 

id - ���������� �������� ������������� ������ (������ ������).
file - ���� ��� ��������.

������ ������� - ��� ���������� - sharedserver.exe

������ �������(��) - ����������� � �����������. 
���� ��� ���������� - �� ������ ���������.
��������� - ������ ������� ������ �� ����������������� �����.
��������: sharedclient.exe 1 2 3 4 5 6 - �������� 6 ������������ ������� ������.

������ ���������� ��������:
sharedclient.exe 1 2 3 4 5 6
sharedclient.exe 7 8 9 10 11 12
���������� 12 ������� ������ � 2-� ���������.
��������� �������� ������ ��������� �� ������ bat ��� cmd �����.
������ - �����, �� ��� ���������� ���������������. ������ ������ - ������ ����� ���������� �������.