# Build Android APK Bang Expo EAS

File nay chi huong dan build app mobile ra file APK de cai truc tiep len dien thoai Android. Khong can Google Play, khong can build AAB.

Repo mobile nam o:

```bash
apps/mobile
```

Backend production/demo dang dung:

```txt
https://api.binchat.me
```

## 1. Ket qua minh da config san

File `apps/mobile/app.json` da cau hinh:

```json
{
  "expo": {
    "name": "BinChat",
    "slug": "binchat-mobile",
    "owner": "ngocanh25092004",
    "scheme": "binchat",
    "android": {
      "package": "me.binchat.mobile",
      "permissions": [
        "android.permission.RECORD_AUDIO",
        "android.permission.MODIFY_AUDIO_SETTINGS"
      ]
    },
    "extra": {
      "apiUrl": "https://api.binchat.me",
      "socketUrl": "https://api.binchat.me",
      "eas": {
        "projectId": "d0602f73-442b-4efc-b787-f60a135d65d5"
      }
    }
  }
}
```

Y nghia:

- `name`: ten app hien tren dien thoai.
- `slug`: ten project tren Expo.
- `owner`: tai khoan Expo dang so huu project.
- `android.package`: dinh danh app Android, khong dung dau cach, khong viet hoa.
- `projectId`: ID project EAS, da duoc tao bang `eas init`.

File `apps/mobile/eas.json` da co profile `preview` de build APK:

```json
{
  "build": {
    "preview": {
      "distribution": "internal",
      "android": {
        "buildType": "apk"
      },
      "env": {
        "EXPO_PUBLIC_API_URL": "https://api.binchat.me",
        "EXPO_PUBLIC_SOCKET_URL": "https://api.binchat.me"
      }
    }
  }
}
```

## 2. Cai cong cu tren may

Can co Node.js va npm. Kiem tra:

```bash
node -v
npm -v
```

Neu chua co EAS CLI, co the dung truc tiep qua `npx`, khong bat buoc cai global.

Dang nhap Expo:

```bash
cd apps/mobile
npx eas login
npx eas whoami
```

Tai khoan hien tai minh da test duoc:

```txt
ngocanh25092004
```

## 3. Cai dependency mobile

Chay trong thu muc mobile:

```bash
cd apps/mobile
npm install
```

Neu Expo bao dependency lech version, chay:

```bash
npx expo install --check
```

Neu can sua tu dong cac dependency Expo theo SDK hien tai:

```bash
npx expo install expo-asset expo-haptics expo expo-file-system expo-image-picker expo-linking
```

## 4. Kiem tra truoc khi build

Chay:

```bash
cd apps/mobile
npx expo-doctor
```

Ket qua tot la:

```txt
18/18 checks passed. No issues detected!
```

Minh da chay ngay tren project nay va da qua `18/18`.

## 5. Build APK de cai truc tiep

Chay lenh nay:

```bash
cd apps/mobile
npm run build:android
```

Lenh tren tuong duong:

```bash
npx eas build --platform android --profile preview
```

Lan dau EAS co the hoi ve Android credentials/keystore. Neu moi lam demo, chon de Expo tu quan ly credentials.

Sau khi build xong, terminal se in ra link Expo. Mo link do de tai file `.apk`.

## 6. Build khong cho terminal doi lau

Neu chi muon day job len Expo roi tat terminal:

```bash
cd apps/mobile
npx eas build --platform android --profile preview --non-interactive --no-wait
```

Sau do xem trang thai:

```bash
npx eas build:list --platform android --limit 1
```

Build minh vua gui len EAS:

```txt
Project: @ngocanh25092004/binchat-mobile
Profile: preview
Status: in progress
Build URL: https://expo.dev/accounts/ngocanh25092004/projects/binchat-mobile/builds/d9c5bbfa-9752-44a3-839b-31a846efb7f4
```

Khi status thanh `finished`, trong trang build se co nut tai APK.

## 7. Cai APK len dien thoai

Cach de nhat:

1. Mo link build tren dien thoai Android.
2. Tai file APK.
3. Neu may chan, vao Settings.
4. Tim `Install unknown apps`.
5. Cho phep Chrome hoac File Manager cai app.
6. Bam lai file APK de cai.

## 8. Cai APK bang adb

Neu dung emulator hoac cam cap USB:

```bash
adb devices
adb install path/to/binchat.apk
```

Neu da cai ban cu:

```bash
adb install -r path/to/binchat.apk
```

Neu loi do trung package/signature:

```bash
adb uninstall me.binchat.mobile
adb install path/to/binchat.apk
```

## 9. Test sau khi cai

Mo app va test cac muc nay:

- App mo khong crash.
- Dang ky/dang nhap duoc.
- API dang goi ve `https://api.binchat.me`, khong phai localhost.
- Gui/nhan tin nhan realtime duoc.
- Upload anh/file duoc.
- Ghi am voice message xin quyen micro va gui duoc.

Neu API loi, mo trinh duyet tren dien thoai va test:

```txt
https://api.binchat.me/api/health
```

Neu link tren khong mo duoc, loi nam o backend/domain/SSL, khong phai APK.

## 10. Loi thuong gap

### App goi nham localhost

Mobile production khong duoc dung `localhost`, vi `localhost` tren dien thoai la chinh dien thoai.

Kiem tra trong `apps/mobile/eas.json`:

```json
"EXPO_PUBLIC_API_URL": "https://api.binchat.me",
"EXPO_PUBLIC_SOCKET_URL": "https://api.binchat.me"
```

Sua xong phai build lai APK.

### EAS bao project not configured

Chay:

```bash
cd apps/mobile
npx eas init
```

Project hien tai da duoc init san voi:

```txt
d0602f73-442b-4efc-b787-f60a135d65d5
```

### expo-doctor bao thieu package

Chay:

```bash
cd apps/mobile
npx expo install --check
```

Sau do chay lai:

```bash
npx expo-doctor
```

### Socket khong realtime

Kiem tra:

- `EXPO_PUBLIC_SOCKET_URL=https://api.binchat.me`.
- Backend gateway co expose `/socket.io`.
- Reverse proxy Caddy/Nginx co proxy WebSocket.
- EC2 Security Group mo HTTPS port `443`.

### Khong cai duoc APK

Thu:

```bash
adb uninstall me.binchat.mobile
adb install path/to/binchat.apk
```

Neu cai bang dien thoai, bat quyen `Install unknown apps`.

## 11. Lenh hay dung

```bash
cd apps/mobile
npx expo-doctor
npm run build:android
npx eas build:list --platform android --limit 1
```

