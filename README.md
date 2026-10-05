# MinimapMarkerHelper

미니맵 위에 공격대 징표의 위치를 표시하고, 징표별 위치를 8개 구역에 배치할 수 있는 개인용 World of Warcraft 애드온이다. 미니맵 버튼을 눌러 배치와 표시 옵션을 조정한다.

## Requirements

- World of Warcraft Retail (`Interface: 120100`)

## Installation

### WowUp

1. WowUp에서 **Get Addons**를 연다.
2. **Install from URL**을 선택한다.
3. 이 GitHub 저장소 URL을 입력하고 **Import**를 누른다.
4. 표시된 애드온에서 **Install**을 누른다.

### Manual

GitHub Release의 `MinimapMarkerHelper-v*.zip`을 내려받아 `World of Warcraft/_retail_/Interface/AddOns/`에 압축을 푼다. 설치 후 경로는 `Interface/AddOns/MinimapMarkerHelper/MinimapMarkerHelper.toc`이어야 한다.

## Update

WowUp으로 설치했다면 새 GitHub Release가 배포된 뒤 WowUp에서 업데이트할 수 있다.

## Usage

미니맵 오른쪽 위의 지도 아이콘을 눌러 설정 창을 연다. `애드온 사용`을 끄면 징표 오버레이를 숨기고 기본 미니맵 아이콘 크기와 배경 텍스처를 블리자드 기본 상태로 되돌린다. 이때 배치 프로필을 포함한 하위 옵션은 비활성화되지만 저장된 값은 유지되며, 다시 켜면 적용된다. 애드온을 사용하는 동안 공격대 징표를 고른 뒤 보드의 원하는 구역을 클릭해 배치하고, 징표 크기·기본 미니맵 아이콘 크기·지면 텍스처 표시 옵션을 조정한다. 해골 징표가 놓인 구역은 입구를 뜻하며 금색 테두리로 강조된다. 기본 미니맵 아이콘 크기는 플레이어 방향 화살표를 포함한 블리자드 기본 미니맵 아이콘에 적용된다. 배치 프로필 드롭다운에서 배치를 선택하면 즉시 불러오며, 이름을 입력해 새 배치를 추가하거나 현재 배치를 저장·삭제할 수 있다.
