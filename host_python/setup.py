from setuptools import setup, find_packages

setup(
    name='xcore_ai_ie',
    version='0.1.0',
    description='Python API for XCORE-AI IE',
    author='XMOS',
    packages=find_packages(include=['xcore_ai_ie', 'xcore_ai_ie.*']),
    install_requires=[
        'pyusb>=1.1.0',
    ],
)
