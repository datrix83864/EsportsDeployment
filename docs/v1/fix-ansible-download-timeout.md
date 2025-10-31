# Fix: Ansible Cloud Image Download Timeout

## Issue

Ansible playbook failed to download Ubuntu cloud image with error:
```
failed to create temporary content file: The read operation timed out
```

The `get_url` module had a default **10-second timeout** for downloading a **~700MB** file, which is impossible on most connections.

## Root Cause

In `ansible/playbooks/create_proxmox_template.yml`, line 35:

```yaml
- name: Download cloud image
  get_url:
    url: "{{ image_url }}"
    dest: "{{ tmp_base }}/cloudimg-{{ vmid }}/{{ image_url | basename }}"
    mode: "0644"
    # timeout was 10 seconds (default) - WAY too short!
```

## Fix Applied

### 1. Increased Timeout to 10 Minutes

```yaml
- name: Download cloud image (this may take several minutes for ~700MB file)
  get_url:
    url: "{{ image_url }}"
    dest: "{{ tmp_base }}/cloudimg-{{ vmid }}/{{ image_url | basename }}"
    mode: "0644"
    timeout: 600  # 10 minutes timeout for large file download
```

### 2. Added Retry Logic

```yaml
  retries: 3  # Retry up to 3 times on failure
  delay: 10   # Wait 10 seconds between retries
  until: download_result is succeeded
```

### 3. Added Wget Fallback

If Ansible's `get_url` fails, the playbook now falls back to using `wget` directly:

```yaml
- name: Fallback to wget if get_url fails
  shell: |
    cd {{ tmp_base }}/cloudimg-{{ vmid }}
    wget -q --show-progress -O "{{ image_url | basename }}" "{{ image_url }}"
  when: 
    - not image_file.stat.exists
    - download_result is failed
```

### 4. Added Image Validation

After download, the playbook now:

1. **Downloads SHA256SUMS** from Ubuntu
2. **Verifies checksum** of downloaded image
3. **Validates file size** (must be > 200MB)
4. **Checks template boot disk** after creation

### 5. Better User Feedback

```yaml
- name: Display download message
  debug:
    msg: |
      Downloading Ubuntu cloud image from {{ image_url }}
      This is a ~700MB file and may take 5-10 minutes depending on your connection.
      Timeout is set to 10 minutes with 3 retry attempts.
```

## Expected Download Times

| Connection Speed | Approximate Time |
| ---------------- | ---------------- |
| 10 Mbps          | ~9-10 minutes    |
| 50 Mbps          | ~2 minutes       |
| 100 Mbps         | ~1 minute        |
| 1 Gbps           | ~10 seconds      |

The 10-minute timeout should accommodate most connection speeds.

## Usage

Just run the deployment script again:

```bash
./deploy.sh
```

The enhanced Ansible playbook will:
1. Show progress messages
2. Wait up to 10 minutes for download
3. Retry 3 times on failure
4. Fall back to wget if needed
5. Validate the downloaded image
6. Verify the template is bootable

## If It Still Times Out

If you have a very slow connection (< 10 Mbps) and the download still times out:

### Option 1: Pre-download the Image

Download the cloud image manually on the Proxmox host:

```bash
# SSH to Proxmox
ssh root@<proxmox-ip>

# Download image
cd /var/tmp
mkdir -p cloudimg-manual
cd cloudimg-manual
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# The playbook will detect and use this existing file
```

### Option 2: Increase Timeout Further

Edit `ansible/playbooks/create_proxmox_template.yml` and increase the timeout:

```yaml
timeout: 1800  # 30 minutes for very slow connections
```

### Option 3: Use ISO Alternative

If cloud image downloads consistently fail due to connection issues:

```bash
# Download ISO once (can be done overnight)
./scripts/download_ubuntu_iso.sh <proxmox-ip> root@<proxmox-ip> local 22.04

# Update config.yaml
# ubuntu_iso: "local:iso/ubuntu-22.04.5-live-server-amd64.iso"
```

**Note:** See `docs/using-iso-with-autoinstall.md` for limitations of this approach.

## Files Modified

- `ansible/playbooks/create_proxmox_template.yml` - Enhanced with timeout, retries, validation, and fallback

## Testing

The playbook now includes comprehensive validation:

✅ Download timeout extended to 10 minutes  
✅ 3 automatic retries on failure  
✅ Wget fallback if Ansible module fails  
✅ SHA256 checksum verification  
✅ File size validation  
✅ Template boot disk verification  
✅ Progress messages for user feedback  

This should resolve the timeout issue for most users.
